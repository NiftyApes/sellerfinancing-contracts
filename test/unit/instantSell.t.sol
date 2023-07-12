// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/seaport/ISeaport.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";
import "../common/Console.sol";

contract TestInstantSell is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_instantSell_loanClosed_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                (loan.loanItem.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesInInstantSell;
        for (uint256 i = 0; i < recipients1.length; i++) {
            royaltiesInInstantSell += amounts1[i];
        }

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        uint256 protocolFee = sellerFinancing.calculateProtocolFee(loan.loanItem.principalAmount + periodInterest);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + periodInterest + protocolFee + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
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
        emit InstantSell(offer.collateralItem.token, offer.collateralItem.identifier, 0);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            loan.loanItem.principalAmount + periodInterest + protocolFee,
            protocolFee,
            royaltiesInInstantSell,
            periodInterest,
            loan
        );

        sellerFinancing.instantSell(
            loanId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer2, loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore - offer.loanItem.downPaymentAmount + minProfitAmount)
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

    function _test_instantSell_loanClosed_withProtocolFee(FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);
    
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        uint256 ownerBalanceBefore = address(owner).balance;
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                (loan.loanItem.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesInInstantSell;
        for (uint256 i = 0; i < recipients1.length; i++) {
            royaltiesInInstantSell += amounts1[i];
        }

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        uint256 protocolFee = sellerFinancing.calculateProtocolFee(loan.loanItem.principalAmount + periodInterest);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + periodInterest + protocolFee + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
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
        emit InstantSell(offer.collateralItem.token, offer.collateralItem.identifier, 0);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            loan.loanItem.principalAmount + periodInterest + protocolFee,
            protocolFee,
            royaltiesInInstantSell,
            periodInterest,
            loan
        );
        
        sellerFinancing.instantSell(
            loanId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer2, loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore - offer.loanItem.downPaymentAmount + minProfitAmount)
        );
        // protocol fee received by the owner
        assertEq(address(owner).balance, ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_instantSell_loanClosed_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_instantSell_loanClosed_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_instantSell_loanClosed_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_loanClosed_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_instantSell_loanClosed_multipleConsideration(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // set any minimum profit value
        uint256 considerationAmount2 = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + periodInterest + considerationAmount2) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPrice);

        ISeaport.ConsiderationItem[] memory considItems = new ISeaport.ConsiderationItem[](3);
        considItems[0] = order[0].parameters.consideration[0];
        considItems[1] = order[0].parameters.consideration[1];
        considItems[2] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.ERC20,
            token: WETH_ADDRESS,
            identifierOrCriteria: 0,
            startAmount: considerationAmount2,
            endAmount: considerationAmount2,
            recipient: payable(buyer2)
        });

        order[0].parameters.consideration = new ISeaport.ConsiderationItem[](3);
        order[0].parameters.consideration[0] = considItems[0];
        order[0].parameters.consideration[1] = considItems[1];
        order[0].parameters.consideration[2] = considItems[2];
        order[0].parameters.totalOriginalConsiderationItems = 3;

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        sellerFinancing.instantSell(
            loanId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer2, loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore - offer.loanItem.downPaymentAmount)
        );
    }

    function test_fuzz_instantSell_loanClosed_multipleConsideration(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_loanClosed_multipleConsideration(fuzzed);
    }

    function test_unit_instantSell_loanClosed_multipleConsideration() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_loanClosed_multipleConsideration(fixedForSpeed);
    }

    function _test_instantSell_loanClosed_withoutSeaportFee(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.identifier, offer.loanItem.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                (loan.loanItem.principalAmount + periodInterest)
            );

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        uint256 bidPrice = (loan.loanItem.principalAmount + periodInterest + minProfitAmount);

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
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
            loanId,
            minProfitAmount,
            abi.encode(order[0])
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer2, loanId);
        uint256 buyer1BalanceAfter = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfter,
            (buyer1BalanceBefore - offer.loanItem.downPaymentAmount + minProfitAmount)
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        skip(loan.periodDuration * 2);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.loanItem.principalAmount + totalInterest) + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
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
        vm.expectRevert(INiftyApesErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.instantSell(
            loanId,
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

    function _test_instantSell_reverts_ifCallerSanctioned(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.loanItem.principalAmount + totalInterest) + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(
            buyer1,
            SANCTIONED_ADDRESS,
            loanId
        );

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();
        
        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.instantSell(
            loanId,
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

    function _test_instantSell_reverts_ifCallerIsNotBuyer(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.loanItem.principalAmount + totalInterest) + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );

        vm.startPrank(buyer2);
        vm.expectRevert(
            abi.encodeWithSelector(INiftyApesErrors.InvalidCaller.selector, buyer2, buyer1)
        );
        sellerFinancing.instantSell(
            loanId,
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.warp(loan.periodEndTimestamp + loan.periodDuration + 1);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.loanItem.principalAmount + totalInterest) + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.instantSell(
            loanId,
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[0].itemType = ISeaport.ItemType.ERC20;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidConsiderationItemType.selector,
                0,
                ISeaport.ItemType.ERC20,
                ISeaport.ItemType.ERC721
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[0].token = address(1);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidConsiderationToken.selector,
                0,
                address(1),
                offer.collateralItem.token
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[0].identifierOrCriteria = 1;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidConsideration0Identifier.selector,
                1,
                offer.collateralItem.identifier
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.offer[0].itemType = ISeaport.ItemType.ERC721;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOffer0ItemType.selector,
                ISeaport.ItemType.ERC721,
                ISeaport.ItemType.ERC20
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.offer[0].token = address(1);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOffer0Token.selector,
                address(1),
                WETH_ADDRESS
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[1].itemType = ISeaport.ItemType.ERC721;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidConsiderationItemType.selector,
                1,
                ISeaport.ItemType.ERC721,
                ISeaport.ItemType.ERC20
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.consideration[1].token = address(1);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidConsiderationToken.selector,
                1,
                address(1),
                WETH_ADDRESS
            )
        );
        sellerFinancing.instantSell(loanId, 0, abi.encode(order[0]));
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
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.loanItem.principalAmount + totalInterest) + minProfitAmount) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
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
                INiftyApesErrors.InsufficientAmountReceivedFromSale.selector,
                loan.loanItem.principalAmount + totalInterest + minProfitAmount,
                loan.loanItem.principalAmount + totalInterest + minProfitAmount + 1
            )
        );
        sellerFinancing.instantSell(
            loanId,
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
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifSaleAmountLessThanMinSaleAmountRequested(fixedForSpeed);
    }

    function _test_instantSell_reverts_ifOrderOfferLengthNotEqualToOne(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        
        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanItem.principalAmount + totalInterest) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.identifier,
            bidPrice,
            buyer2,
            true
        );
        order[0].parameters.offer = new ISeaport.OfferItem[](2);
        order[0].parameters.offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC20,
            token: WETH_ADDRESS,
            identifierOrCriteria: 0,
            startAmount: bidPrice,
            endAmount: bidPrice
        });
        order[0].parameters.offer[1] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC20,
            token: WETH_ADDRESS,
            identifierOrCriteria: 0,
            startAmount: bidPrice,
            endAmount: bidPrice
        });

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOfferLength.selector,
                2,
                1
            )
        );
        sellerFinancing.instantSell(
            loanId,
            0,
            abi.encode(order[0])
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_ifOrderOfferLengthNotEqualToOne(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_ifOrderOfferLengthNotEqualToOne(fuzzed);
    }

    function test_unit_instantSell_reverts_ifOrderOfferLengthNotEqualToOne() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_ifOrderOfferLengthNotEqualToOne(fixedForSpeed);
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
