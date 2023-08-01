// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

contract TestBorrow is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    
    function _test_borrow_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, address(borrower1), loanId);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrow_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_simplest_case(fuzzed);
    }

    function test_unit_borrow_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_simplest_case(fixedForSpeed);
    }

    function _test_borrow_emits_expectedEvents(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        Loan memory loan = sellerFinancing.getLoan(0);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);

        vm.expectEmit(true, true, false, false);
        emit OfferSignatureUsed(offer.collateralItem.token, offer.collateralItem.tokenId, offer, offerSignature);

        vm.expectEmit(true, true, false, false);
        emit LoanExecuted(offer.collateralItem.token, offer.collateralItem.tokenId, offer.collateralItem.amount, offerSignature, loan);

        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);
    }

    function test_fuzz_borrow_emits_expectedEvents(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_emits_expectedEvents(fuzzed);
    }

    function test_unit_borrow_emits_expectedEvents() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_emits_expectedEvents(fixedForSpeed);
    }

    function _test_borrow_reverts_if_offerType_Not_Lending(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFieldsForLending);

        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);

        vm.expectRevert(abi.encodeWithSelector(INiftyApesErrors.InvalidOfferType.selector, INiftyApesStructs.OfferType.SELLER_FINANCING, INiftyApesStructs.OfferType.LENDING));
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_offerType_Not_Lending(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_offerType_Not_Lending(fuzzed);
    }

    function test_unit_borrow_reverts_if_offerType_Not_Lending() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_offerType_Not_Lending(fixedForSpeed);
    }

    function _test_borrow_collection_offer_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.tokenId = 0;
        uint256 tokenId1 = 8661;
        uint256 tokenId2 = 6974;

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, borrower1, tokenId2);
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenId1);
        (uint256 loanId1) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            tokenId1,
            offer.collateralItem.amount
        );
        boredApeYachtClub.approve(address(sellerFinancing), tokenId2);
        (uint256 loanId2) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            tokenId2,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenId1, borrower1, loanId1);
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenId2, borrower1, loanId2);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by two times the loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - 2 * offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by two times the loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + 2 * offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrow_collection_offer_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_collection_offer_case(fuzzed);
    }

    function test_unit_borrow_collection_offer_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_collection_offer_case(fixedForSpeed);
    }

    function _test_borrow_collection_offer_reverts_if_limitReached(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;
        offer.collateralItem.tokenId = 0;
        uint256 tokenId1 = 8661;
        uint256 tokenId2 = 6974;

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, borrower1, tokenId2);
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenId1);
        (uint256 loanId1) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            tokenId1,
            offer.collateralItem.amount
        );
        boredApeYachtClub.approve(address(sellerFinancing), tokenId2);
        vm.expectRevert(INiftyApesErrors.CollectionOfferLimitReached.selector);
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            tokenId2,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenId1, borrower1, loanId1);

        // borrower1 still owns second token
        assertEq(boredApeYachtClub.ownerOf(tokenId2), borrower1);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by only one loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by only one loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrow_collection_offer_reverts_if_limitReached(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_collection_offer_reverts_if_limitReached(fuzzed);
    }

    function test_unit_borrow_collection_offer_reverts_if_limitReached() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_collection_offer_reverts_if_limitReached(fixedForSpeed);
    }

    function _test_borrow_reverts_if_signature_already_used(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        vm.warp(loan.periodEndTimestamp + 1);

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.startPrank(lender1);
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();

        vm.startPrank(borrower1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SignatureNotAvailable.selector,
                offerSignature
            )
        );
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_signature_already_used(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_signature_already_used(fuzzed);
    }

    function test_unit_borrow_reverts_if_signature_already_used() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_signature_already_used(fixedForSpeed);
    }

    function _test_borrow_reverts_if_offerExpired(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.warp(uint256(offer.expiration) + 1);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        vm.expectRevert(INiftyApesErrors.OfferExpired.selector);
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_offerExpired(fuzzed);
    }

    function test_unit_borrow_reverts_if_offerExpired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_offerExpired(fixedForSpeed);
    }

    function _test_borrow_reverts_if_invalidPeriodDuration(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.periodDuration = 1 minutes - 1;
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        vm.expectRevert(INiftyApesErrors.InvalidPeriodDuration.selector);
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_invalidPeriodDuration(fuzzed);
    }

    function test_unit_borrow_reverts_if_invalidPeriodDuration() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_invalidPeriodDuration(fixedForSpeed);
    }

    function _test_borrow_reverts_if_principalAmount_isZero(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.principalAmount = 0;
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        vm.expectRevert(INiftyApesErrors.PrincipalAmountZero.selector);
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_principalAmount_isZero(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_principalAmount_isZero(fuzzed);
    }

    function test_unit_borrow_reverts_if_principalAmount_isZero() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_principalAmount_isZero(fixedForSpeed);
    }

    function _test_borrow_reverts_if_invalidMinPrincipalPerPeriod(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.minimumPrincipalPerPeriod = uint128(offer.loanTerms.principalAmount + 1);
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidMinimumPrincipalPerPeriod.selector,
                offer.loanTerms.minimumPrincipalPerPeriod,
                offer.loanTerms.principalAmount
            )
        );
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_invalidMinPrincipalPerPeriod(fuzzed);
    }

    function test_unit_borrow_reverts_if_invalidMinPrincipalPerPeriod() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_invalidMinPrincipalPerPeriod(fixedForSpeed);
    }

    function _test_borrow_reverts_if_borrowerSanctioned(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
       vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.borrow(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_borrowerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_borrowerSanctioned(fuzzed);
    }

    function test_unit_borrow_reverts_if_borrowerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_borrowerSanctioned(fixedForSpeed);
    }

    function _test_borrow_reverts_if_callerSanctioned(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(SANCTIONED_ADDRESS);
       vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_borrow_reverts_if_callerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_reverts_if_callerSanctioned(fuzzed);
    }

    function test_unit_borrow_reverts_if_callerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_reverts_if_callerSanctioned(fixedForSpeed);
    }
}