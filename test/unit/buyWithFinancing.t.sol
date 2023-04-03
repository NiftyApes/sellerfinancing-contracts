// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingErrors.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingEvents.sol";

contract TestBuyWithFinancing is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), address(sellerFinancing));
        // balance increments to one
        assertEq(sellerFinancing.balanceOf(buyer1, address(boredApeYachtClub)), 1);
        // nftId exists at index 0
        assertEq(
            sellerFinancing.tokenOfOwnerByIndex(buyer1, address(boredApeYachtClub), 0),
            offer.nftId
        );
        // loan auction exists
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(offer.nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId));

        // check loan struct values
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWithFinancing_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        
        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, offer.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients1[0]).balance;

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithFinancing_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_simplest_case(fuzzed);
    }

    function test_unit_buyWithFinancing_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_simplest_case(fixedForSpeed);
    }

    function _test_buyWithFinancing_returnsExtraAmountMoreThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        // set any value > 0
        uint256 extraAmount = 1234567890;
        uint256 buyer1BalanceBefore = address(buyer1).balance;
        vm.startPrank(buyer1);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount + extraAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();

        // assert only offer.downPaymentAmount is consumed and extraAmount is returned
        uint256 buyer1BalanceAfter = address(buyer1).balance;
        assertEq(buyer1BalanceAfter, buyer1BalanceBefore - offer.downPaymentAmount);
    }

    function test_fuzz_buyWithFinancing_returnsExtraAmountMoreThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_returnsExtraAmountMoreThanDownpayment(fuzzed);
    }

    function test_unit_buyWithFinancing_returnsExtraAmountMoreThanDownpayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_returnsExtraAmountMoreThanDownpayment(fixedForSpeed);
    }

    function _test_buyWithFinancing_emitsExpectedEvents(FuzzedOfferFields memory fuzzed) private {
        ISellerFinancingStructs.Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
       
        vm.expectEmit(true, true, false, false);
        emit OfferSignatureUsed(offer.nftContractAddress, offer.nftId, offer, offerSignature);

        vm.expectEmit(true, true, false, false);
        emit LoanExecuted(offer.nftContractAddress, offer.nftId, offerSignature, loan);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_emitsExpectedEvents(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_emitsExpectedEvents(fuzzed);
    }

    function test_unit_buyWithFinancing_emitsExpectedEvents() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_emitsExpectedEvents(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_offerSignerNotOwner(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.prank(seller1);
        IERC721Upgradeable(offer.nftContractAddress).safeTransferFrom(
            seller1,
            seller2,
            offer.nftId
        );

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.NotNftOwner.selector,
                offer.nftContractAddress,
                offer.nftId,
                seller1
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_offerSignerNotOwner(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_offerSignerNotOwner(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_offerSignerNotOwner() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_offerSignerNotOwner(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_signatureAlreadyUsed(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.warp(loan.periodEndTimestamp + 1);

        vm.startPrank(seller1);
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.SignatureNotAvailable.selector,
                offerSignature
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_signatureAlreadyUsed(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_signatureAlreadyUsed(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_signatureAlreadyUsed() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_signatureAlreadyUsed(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        vm.warp(uint256(offer.expiration) + 1);

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.OfferExpired.selector);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_offerExpired(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_offerExpired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_offerExpired(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.periodDuration = 1 minutes - 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.InvalidPeriodDuration.selector);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_invalidPeriodDuration(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_invalidPeriodDuration() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_invalidPeriodDuration(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_invalidDownpaymentValue(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InsufficientMsgValue.selector,
                offer.downPaymentAmount - 1,
                offer.downPaymentAmount
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount - 1 }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_invalidDownpaymentValue(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_invalidDownpaymentValue(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_invalidDownpaymentValue() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_invalidDownpaymentValue(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.price = offer.downPaymentAmount - 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.DownPaymentGreaterThanOrEqualToOfferPrice.selector,
                offer.downPaymentAmount,
                offer.price
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.minimumPrincipalPerPeriod = (offer.price - offer.downPaymentAmount) + 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.InvalidMinimumPrincipalPerPeriod.selector,
                offer.minimumPrincipalPerPeriod,
                offer.price - offer.downPaymentAmount
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_buyerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.minimumPrincipalPerPeriod = (offer.price - offer.downPaymentAmount) + 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_buyerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_buyerSanctioned(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_buyerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_buyerSanctioned(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_callerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.minimumPrincipalPerPeriod = (offer.price - offer.downPaymentAmount) + 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_callerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_callerSanctioned(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_callerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_callerSanctioned(fixedForSpeed);
    }
}
