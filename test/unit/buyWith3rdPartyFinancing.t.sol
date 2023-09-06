// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

contract TestBuyWith3rdPartyFinancing is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyWith3rdPartyFinancing_WETH_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        uint256 loanId = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance decreased by token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - (order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancing_WETH_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_WETH_simplest_case(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_WETH_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_WETH_simplest_case(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_WETH_ERC1155_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLendingERC1155);
        vm.prank(borrower1);
        erc1155Token.safeTransferFrom(borrower1, seller2, offer.collateralItem.tokenId, offer.collateralItem.amount, bytes(""));
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2ForERC1155(WETH_ADDRESS, offer.loanTerms.principalAmount*2);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        uint256 loanId = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedLoanERC1155(offer, offer.collateralItem.tokenId, offer.collateralItem.amount, borrower1, loanId, offer.collateralItem.amount);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance decreased by token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - (order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancing_WETH_ERC1155_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_WETH_ERC1155_case(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_WETH_ERC1155_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_WETH_ERC1155_case(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_USDC_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLendingUSDC);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(USDC_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintUsdc(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        mintUsdc(lender1, offer.loanTerms.principalAmount);

        uint256 lender1BalanceBefore = usdc.balanceOf(lender1);
        uint256 borrower1BalanceBefore = usdc.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        usdc.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        uint256 loanId = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        uint256 lender1BalanceAfter = usdc.balanceOf(lender1);
        uint256 borrower1BalanceAfter = usdc.balanceOf(borrower1);

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance decreased by token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - (order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancing_USDC_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        _test_buyWith3rdPartyFinancing_USDC_simplest_case(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_USDC_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTestingUSDC;
        _test_buyWith3rdPartyFinancing_USDC_simplest_case(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_emits_expectedEvents(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        
        Loan memory loan = sellerFinancing.getLoan(0);
        vm.expectEmit(true, true, false, false);
        emit OfferSignatureUsed(offer.collateralItem.token, offer.collateralItem.tokenId, offer, offerSignature);

        vm.expectEmit(true, true, false, false);
        emit LoanExecuted(offer.collateralItem.token, offer.collateralItem.tokenId, offer.collateralItem.amount, offerSignature, loan);
        
        uint256 loanId = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);
    }

    function test_fuzz_buyWith3rdPartyFinancing_emits_expectedEvents(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_emits_expectedEvents(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_emits_expectedEvents() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_emits_expectedEvents(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_offerType_Not_Lending(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFieldsForLending);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        vm.expectRevert(abi.encodeWithSelector(INiftyApesErrors.InvalidOfferType.selector, INiftyApesStructs.OfferType.SELLER_FINANCING, INiftyApesStructs.OfferType.LENDING));
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_offerType_Not_Lending(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_offerType_Not_Lending(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_offerType_Not_Lending() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_offerType_Not_Lending(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_loanItemType_notERC20(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.itemType = ItemType.NATIVE;
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        vm.expectRevert(INiftyApesErrors.InvalidLoanItemType.selector);
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_loanItemType_notERC20(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_loanItemType_notERC20(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_loanItemType_notERC20() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_loanItemType_notERC20(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_collectionOffer_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.tokenId = 0;
        uint256 tokenId1 = 8661;
        uint256 tokenId2 = 6974;

        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), 2*offer.loanTerms.principalAmount);
        vm.stopPrank();

        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, tokenId1);
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, tokenId2);

        ISeaport.Order memory order1 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, tokenId1);
        ISeaport.Order memory order2 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, tokenId2);

        mintWeth(borrower1, 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        uint256 loanId1 = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            tokenId1,
            offer.collateralItem.amount,
            abi.encode(order1)
        );
        uint256 loanId2 = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            tokenId2,
            offer.collateralItem.amount,
            abi.encode(order2)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenId1, borrower1, loanId1);
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenId2, borrower1, loanId2);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by two times loan principal amount
        assertEq(
            lender1BalanceAfter,
            lender1BalanceBefore - 2*offer.loanTerms.principalAmount
        );

        // borrower1 balance decreased by two times token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - 2* (order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancing_collectionOffer_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_collectionOffer_case(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_collectionOffer_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_collectionOffer_case(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_collectionOffer_reverts_if_limitReached(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        // setting offer limit to one
        offer.collectionOfferLimit = 1;
        offer.collateralItem.tokenId = 0;
        uint256 tokenId1 = 8661;
        uint256 tokenId2 = 6974;

        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), 2*offer.loanTerms.principalAmount);
        vm.stopPrank();

        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, tokenId1);
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, tokenId2);

        ISeaport.Order memory order1 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, tokenId1);
        ISeaport.Order memory order2 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, tokenId2);

        mintWeth(borrower1, 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        uint256 loanId1 = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            tokenId1,
            offer.collateralItem.amount,
            abi.encode(order1)
        );
        vm.expectRevert(INiftyApesErrors.CollectionOfferLimitReached.selector);
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            tokenId2,
            offer.collateralItem.amount,
            abi.encode(order2)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenId1, borrower1, loanId1);
        // seller21 still owns second token
        assertEq(boredApeYachtClub.ownerOf(tokenId2), seller2);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by only one times the loan principal amount
        assertEq(
            lender1BalanceAfter,
            lender1BalanceBefore - offer.loanTerms.principalAmount
        );

        // borrower1 balance decreased by only token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - (order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancing_collectionOffer_reverts_if_limitReached(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_collectionOffer_reverts_if_limitReached(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_collectionOffer_reverts_if_limitReached() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_collectionOffer_reverts_if_limitReached(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_signature_already_used(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        uint256 loanId = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
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
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SignatureNotAvailable.selector,
                offerSignature
            )
        );
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_signature_already_used(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_signature_already_used(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_signature_already_used() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_signature_already_used(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_offerExpired(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        vm.warp(uint256(offer.expiration) + 1);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        vm.expectRevert(INiftyApesErrors.OfferExpired.selector);
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();

    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_offerExpired(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_offerExpired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_offerExpired(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_invalidPeriodDuration(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.periodDuration = 1 minutes - 1;
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        vm.expectRevert(INiftyApesErrors.InvalidPeriodDuration.selector);
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();

    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_invalidPeriodDuration(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_invalidPeriodDuration() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_invalidPeriodDuration(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_principalAmount_isZero(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.principalAmount = 0;
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        
        vm.startPrank(borrower1);
        vm.expectRevert(INiftyApesErrors.PrincipalAmountZero.selector);
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();

    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_principalAmount_isZero(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_principalAmount_isZero(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_principalAmount_isZero() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_principalAmount_isZero(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_invalidMinPrincipalPerPeriod(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.minimumPrincipalPerPeriod = uint128(offer.loanTerms.principalAmount + 1);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        
        vm.startPrank(borrower1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidMinimumPrincipalPerPeriod.selector,
                offer.loanTerms.minimumPrincipalPerPeriod,
                offer.loanTerms.principalAmount
            )
        );
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();

    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_invalidMinPrincipalPerPeriod(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_invalidMinPrincipalPerPeriod() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_invalidMinPrincipalPerPeriod(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_borrowerSanctioned(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.minimumPrincipalPerPeriod = uint128(offer.loanTerms.principalAmount + 1);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        
        vm.startPrank(borrower1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_borrowerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_borrowerSanctioned(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_borrowerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_borrowerSanctioned(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_reverts_if_callerSanctioned(FuzzedOfferFields memory fuzzed) private {
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.loanTerms.minimumPrincipalPerPeriod = uint128(offer.loanTerms.principalAmount + 1);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        
        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();

    }

    function test_fuzz_buyWith3rdPartyFinancing_reverts_if_callerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_reverts_if_callerSanctioned(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_reverts_if_callerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_reverts_if_callerSanctioned(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancing_WETH_withMarketplaceFees(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        offer.marketplaceRecipients = new MarketplaceRecipient[](1);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount + marketplaceFee);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);

        uint256 marketplaceBalanceBefore = weth.balanceOf(SUPERRARE_MARKETPLACE);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount + marketplaceFee);
        uint256 loanId = sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);
        uint256 marketplaceBalanceAfter = weth.balanceOf(SUPERRARE_MARKETPLACE);

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance decreased by token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - (order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount +  marketplaceFee));
    }

    function test_fuzz_buyWith3rdPartyFinancing_WETH_withMarketplaceFees(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_WETH_withMarketplaceFees(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_WETH_withMarketplaceFees() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_WETH_withMarketplaceFees(fixedForSpeed);
    }

    function createAndValidateSeaportListingFromSeller2(address considerationToken, uint256 tokenPrice, uint256 tokenId) internal returns (ISeaport.Order memory) {
        ISeaport.Order memory order;
        order.parameters.offerer = seller2;
        order.parameters.zone = address(0x004C00500000aD104D7DBd00e3ae0A5C00560C00);
        order.parameters.offer = new ISeaport.OfferItem[](1);
        order.parameters.offer[0].itemType = ISeaport.ItemType.ERC721;
        order.parameters.offer[0].token = address(boredApeYachtClub);
        order.parameters.offer[0].identifierOrCriteria = tokenId;
        order.parameters.offer[0].startAmount = 1;
        order.parameters.offer[0].endAmount = 1;
        order.parameters.consideration = new ISeaport.ConsiderationItem[](1);
        order.parameters.consideration[0].itemType = ISeaport.ItemType.ERC20;
        order.parameters.consideration[0].token = considerationToken;
        order.parameters.consideration[0].identifierOrCriteria = 0;
        order.parameters.consideration[0].startAmount = tokenPrice;
        order.parameters.consideration[0].endAmount = tokenPrice;
        order.parameters.consideration[0].recipient = seller2;
        order.parameters.orderType = ISeaport.OrderType.FULL_OPEN;
        order.parameters.startTime = block.timestamp;
        order.parameters.endTime = block.timestamp + 24 hours;
        order.parameters.zoneHash = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        order.parameters.salt = 96789058676732069;
        order.parameters.conduitKey = bytes32(
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
        );
        order.parameters.totalOriginalConsiderationItems = 1;
        order.signature = bytes("");

        ISeaport.Order[] memory orders = new ISeaport.Order[](1);
        orders[0] = order;
        vm.startPrank(seller2);
        ISeaport(SEAPORT_ADDRESS).validate(orders);
        boredApeYachtClub.approve(SEAPORT_CONDUIT, tokenId);
        vm.stopPrank();
        return order;
    }

    function createAndValidateSeaportListingFromSeller2ForERC1155(address considerationToken, uint256 tokenPrice) internal returns (ISeaport.Order memory) {
        ISeaport.Order memory order;
        order.parameters.offerer = seller2;
        order.parameters.zone = address(0x004C00500000aD104D7DBd00e3ae0A5C00560C00);
        order.parameters.offer = new ISeaport.OfferItem[](1);
        order.parameters.offer[0].itemType = ISeaport.ItemType.ERC1155;
        order.parameters.offer[0].token = address(erc1155Token);
        order.parameters.offer[0].identifierOrCriteria = erc1155Token27638;
        order.parameters.offer[0].startAmount = 10;
        order.parameters.offer[0].endAmount = 10;
        order.parameters.consideration = new ISeaport.ConsiderationItem[](1);
        order.parameters.consideration[0].itemType = ISeaport.ItemType.ERC20;
        order.parameters.consideration[0].token = considerationToken;
        order.parameters.consideration[0].identifierOrCriteria = 0;
        order.parameters.consideration[0].startAmount = tokenPrice;
        order.parameters.consideration[0].endAmount = tokenPrice;
        order.parameters.consideration[0].recipient = seller2;
        order.parameters.orderType = ISeaport.OrderType.FULL_OPEN;
        order.parameters.startTime = block.timestamp;
        order.parameters.endTime = block.timestamp + 24 hours;
        order.parameters.zoneHash = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        order.parameters.salt = 96789058676732069;
        order.parameters.conduitKey = bytes32(
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
        );
        order.parameters.totalOriginalConsiderationItems = 1;
        order.signature = bytes("");

        ISeaport.Order[] memory orders = new ISeaport.Order[](1);
        orders[0] = order;
        vm.startPrank(seller2);
        ISeaport(SEAPORT_ADDRESS).validate(orders);
        erc1155Token.setApprovalForAll(SEAPORT_CONDUIT, true);
        vm.stopPrank();
        return order;
    }
}