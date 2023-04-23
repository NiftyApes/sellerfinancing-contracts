// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/seaport/ISeaport.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingEvents.sol";
import "../common/Console.sol";

contract TestInstantSell is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );
        // loan exists
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function assertionsForClosedLoan(Offer memory offer, address expectedNftOwner) private {
        // expected address has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), expectedNftOwner);

        // require delegate.cash buyer delegation has been revoked
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            false
        );

        // loan doesn't exist anymore
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            0
        );
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), address(0));
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), address(0));
    }

    function _test_instantSell_loanClosed_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, offer.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        (address payable[] memory recipients2, uint256[] memory amounts2) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.nftContractAddress,
                offer.nftId,
                (loan.remainingPrincipal + periodInterest)
            );

        // payout royalties
        uint256 royaltiesInInstantSell;
        for (uint256 i = 0; i < recipients2.length; i++) {
            royaltiesInInstantSell += amounts2[i];
        }
        totalRoyaltiesPaid += royaltiesInInstantSell;

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + periodInterest + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
            offer.nftContractAddress,
            offer.nftId,
            loan.remainingPrincipal + periodInterest,
            royaltiesInInstantSell,
            periodInterest,
            loan
        );
        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.nftContractAddress, offer.nftId, 0);

        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer2);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore - offer.downPaymentAmount + minProfitAmount)
        );
    }

    function test_fuzz_instantSell_loanClosed_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_loanClosed_simplest_case(fuzzed);
    }

    function test_unit_instantSell_loanClosed_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_loanClosed_simplest_case(fixedForSpeed);
    }

    function _test_instantSell_loanClosed_withoutSeaportFee(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, offer.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        (address payable[] memory recipients2, uint256[] memory amounts2) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.nftContractAddress,
                offer.nftId,
                (loan.remainingPrincipal + periodInterest)
            );

        // payout royalties
        for (uint256 i = 0; i < recipients2.length; i++) {
            totalRoyaltiesPaid += amounts2[i];
        }

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        uint256 bidPrice = (loan.remainingPrincipal + periodInterest + minProfitAmount);

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            false
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer2);
        uint256 buyer1BalanceAfter = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfter,
            (buyer1BalanceBefore - offer.downPaymentAmount + minProfitAmount)
        );
    }

    function test_fuzz_instantSell_loanClosed_withoutSeaportFee(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_loanClosed_withoutSeaportFee(fuzzed);
    }

    function test_unit_instantSell_loanClosed_withoutSeaportFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_loanClosed_withoutSeaportFee(fixedForSpeed);
    }

    function _test_instantSell_reverts_post_grace_period(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        skip(loan.periodDuration * 2);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loan);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + totalInterest) + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_post_grace_period(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_post_grace_period(fuzzed);
    }

    function test_unit_instantSell_reverts_post_grace_period() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_post_grace_period(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifCallerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + totalInterest) +
            minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );

        vm.prank(owner);
        sellerFinancing.pauseSanctions();
        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, SANCTIONED_ADDRESS, loan.buyerNftId);
        vm.prank(owner);
        sellerFinancing.unpauseSanctions();
        
        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifCallerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifCallerSanctioned(fuzzed);
    }

    function test_unit_instantSell_reverts_ifCallerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifCallerSanctioned(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifCallerIsNotBuyer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + totalInterest) +
            minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );

        vm.startPrank(buyer2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidCaller.selector,
                buyer2,
                buyer1
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifCallerIsNotBuyer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifCallerIsNotBuyer(fuzzed);
    }

    function test_unit_instantSell_reverts_ifCallerIsNotBuyer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifCallerIsNotBuyer(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifLoanInHardDefault(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        vm.warp(loan.periodEndTimestamp + loan.periodDuration + 1);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + totalInterest) +
            minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifLoanInHardDefault(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifLoanInHardDefault(fuzzed);
    }

    function test_unit_instantSell_reverts_ifLoanInHardDefault() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifLoanInHardDefault(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifOrderConsideration0NotERC721Type(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[0].itemType = ISeaport.ItemType.ERC20;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidConsiderationItemType.selector,
                0,
                ISeaport.ItemType.ERC20,
                ISeaport.ItemType.ERC721
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifOrderConsideration0NotERC721Type(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifOrderConsideration0NotERC721Type(fuzzed);
    }

    function test_unit_instantSell_reverts_ifOrderConsideration0NotERC721Type() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifOrderConsideration0NotERC721Type(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifOrderNftAddressNotEqualToLoanNftAddress(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[0].token = address(1);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidConsiderationToken.selector,
                0,
                address(1),
                offer.nftContractAddress
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifOrderNftAddressNotEqualToLoanNftAddress(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifOrderNftAddressNotEqualToLoanNftAddress(fuzzed);
    }

    function test_unit_instantSell_reverts_ifOrderNftAddressNotEqualToLoanNftAddress() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifOrderNftAddressNotEqualToLoanNftAddress(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifOrderNftIdNotEqualToLoanNftId(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[0].identifierOrCriteria = 1;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidConsideration0Identifier.selector,
                1,
                offer.nftId
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifOrderNftIdNotEqualToLoanNftId(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifOrderNftIdNotEqualToLoanNftId(fuzzed);
    }

    function test_unit_instantSell_reverts_ifOrderNftIdNotEqualToLoanNftId() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifOrderNftIdNotEqualToLoanNftId(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifInvalidOrderOffer0ItemType(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.offer[0].itemType = ISeaport.ItemType.ERC721;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidOffer0ItemType.selector,
                ISeaport.ItemType.ERC721,
                ISeaport.ItemType.ERC20
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifInvalidOrderOffer0ItemType(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifInvalidOrderOffer0ItemType(fuzzed);
    }

    function test_unit_instantSell_reverts_ifInvalidOrderOffer0ItemType() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifInvalidOrderOffer0ItemType(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifInvalidOrderOffer0Token(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.offer[0].token = address(1);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidOffer0Token.selector,
                address(1),
                WETH_ADDRESS
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifInvalidOrderOffer0Token(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifInvalidOrderOffer0Token(fuzzed);
    }

    function test_unit_instantSell_reverts_ifInvalidOrderOffer0Token() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifInvalidOrderOffer0Token(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifOrderConsideration1NotERC20Type(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[1].itemType = ISeaport.ItemType.ERC721;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidConsiderationItemType.selector,
                1,
                ISeaport.ItemType.ERC721,
                ISeaport.ItemType.ERC20
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifOrderConsideration1NotERC20Type(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifOrderConsideration1NotERC20Type(fuzzed);
    }

    function test_unit_instantSell_reverts_ifOrderConsideration1NotERC20Type() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifOrderConsideration1NotERC20Type(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifInvalidOrderConsideration1Token(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[1].token = address(1);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidConsiderationToken.selector,
                1,
                address(1),
                WETH_ADDRESS
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifInvalidOrderConsideration1Token(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifInvalidOrderConsideration1Token(fuzzed);
    }

    function test_unit_instantSell_reverts_ifInvalidOrderConsideration1Token() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifInvalidOrderConsideration1Token(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifSaleAmountLessThanMinSaleAmountRequested(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + totalInterest) +
            minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InsufficientAmountReceivedFromSale.selector,
                loan.remainingPrincipal + totalInterest + minProfitAmount,
                loan.remainingPrincipal + totalInterest + minProfitAmount+1
            )
        );
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount + 1,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifSaleAmountLessThanMinSaleAmountRequested(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifSaleAmountLessThanMinSaleAmountRequested(fuzzed);
    }

    function test_unit_instantSell_reverts_ifSaleAmountLessThanMinSaleAmountRequested() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifSaleAmountLessThanMinSaleAmountRequested(fixedForSpeed);
    }

    function _createOrder(
        address nftContractAddress,
        uint256 nftId,
        uint256 bidPrice,
        address orderCreator,
        bool addSeaportFee
    ) internal view returns (ISeaport.Order[] memory order) {
        uint256 seaportFeeAmount;
        uint256 totalOriginalConsiderationItems = 1;
        if (addSeaportFee) {
            seaportFeeAmount = bidPrice - (bidPrice * 39) / 40;
            totalOriginalConsiderationItems = 2;
        }

        ISeaport.ItemType offerItemType = ISeaport.ItemType.ERC20;
        address offerToken = WETH_ADDRESS;

        order = new ISeaport.Order[](1);
        order[0] = ISeaport.Order({
            parameters: ISeaport.OrderParameters({
                offerer: payable(orderCreator),
                zone: address(0),
                offer: new ISeaport.OfferItem[](1),
                consideration: new ISeaport.ConsiderationItem[](totalOriginalConsiderationItems),
                orderType: ISeaport.OrderType.FULL_OPEN,
                startTime: block.timestamp,
                endTime: block.timestamp + 24 * 60 * 60,
                zoneHash: bytes32(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                ),
                salt: 1,
                conduitKey: bytes32(
                    0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
                ),
                totalOriginalConsiderationItems: totalOriginalConsiderationItems
            }),
            signature: bytes("")
        });
        order[0].parameters.offer[0] = ISeaport.OfferItem({
            itemType: offerItemType,
            token: offerToken,
            identifierOrCriteria: 0,
            startAmount: bidPrice,
            endAmount: bidPrice
        });
        order[0].parameters.consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.ERC721,
            token: nftContractAddress,
            identifierOrCriteria: nftId,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(orderCreator)
        });
        if (totalOriginalConsiderationItems > 1) {
            order[0].parameters.consideration[1] = ISeaport.ConsiderationItem({
                itemType: offerItemType,
                token: offerToken,
                identifierOrCriteria: 0,
                startAmount: seaportFeeAmount,
                endAmount: seaportFeeAmount,
                recipient: payable(0x0000a26b00c1F0DF003000390027140000fAa719)
            });
        }
    }
}
