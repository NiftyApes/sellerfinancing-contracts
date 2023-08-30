// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestBorrowBatch is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_borrowBatch_WETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenIds[0] = offer.collateralItem.tokenId;
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        uint256[] memory loanIds = sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, address(borrower1), loanIds[0]);

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

    function test_fuzz_borrowBatch_WETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_WETH_withOneOffer(fuzzed);
    }

    function test_unit_borrowBatch_WETH_withOneOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_WETH_withOneOffer(fixedForSpeed);
    }

    function _test_borrowBatch_WETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, borrower1 , 6974);

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[0]);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[1]);
        uint256[] memory loanIds = sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenIds[0], address(borrower1), loanIds[0]);
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenIds[1], address(borrower1), loanIds[1]);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by two times loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - 2 * offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by two times loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + 2 * offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrowBatch_WETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_WETH_withTwoOffers(fuzzed);
    }

    function test_unit_borrowBatch_WETH_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_WETH_withTwoOffers(fixedForSpeed);
    }

    function _test_borrowBatch_withERC1155_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLendingERC1155);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.tokenId = 0;
        offer.collateralItem.amount = 0;
        uint256 collateralAmount = 10;

        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenIds[0] = erc1155Token27638;
        tokenIds[1] = erc1155Token27638;
        tokenAmounts[0] = collateralAmount;
        tokenAmounts[1] = collateralAmount;
        vm.startPrank(borrower1);
        erc1155Token.setApprovalForAll(address(sellerFinancing), true);
        uint256[] memory loanIds = sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoanERC1155(offer, tokenIds[0], tokenAmounts[0], borrower1, loanIds[0], tokenAmounts[0]*2);
        assertionsForExecutedLoanERC1155(offer, tokenIds[1], tokenAmounts[1], borrower1, loanIds[1], tokenAmounts[0]*2);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by two times loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - 2 * offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by two times loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + 2 * offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrowBatch_withERC1155_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_withERC1155_withTwoOffers(fuzzed);
    }

    function test_unit_borrowBatch_withERC1155_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_withERC1155_withTwoOffers(fixedForSpeed);
    }

    function _test_borrowBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;
        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, borrower1 , 6974);

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[0]);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[1]);
        uint256[] memory loanIds = sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenIds[0], address(borrower1), loanIds[0]);

        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(borrower1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[1]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by only one times loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by only one times loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrowBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_partialExecution_withSecondOfferInvalid(fuzzed);
    }

    function test_unit_borrowBatch_partialExecution_withSecondOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_partialExecution_withSecondOfferInvalid(fixedForSpeed);
    }

    function _test_borrowBatch_partialExecution_withFirstOfferReverting(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, borrower1 , 6974);

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[1]);
        uint256[] memory loanIds = sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        // loadId max of uint256, indicating trx reverted
        assertEq(loanIds[0], ~uint256(0));
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenIds[1], address(borrower1), loanIds[1]);
        
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), address(borrower1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[0]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by only one times loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance increased by only one times loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + offer.loanTerms.principalAmount);
    }

    function test_fuzz_borrowBatch_partialExecution_withFirstOfferReverting(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_partialExecution_withFirstOfferReverting(fuzzed);
    }

    function test_unit_borrowBatch_partialExecution_withFirstOfferReverting() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_partialExecution_withFirstOfferReverting(fixedForSpeed);
    }

    function _test_borrowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;
        
        bytes memory offerSignature = lender1CreateOffer(offer);
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, borrower1 , 6974);

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[0]);
        boredApeYachtClub.approve(address(sellerFinancing), tokenIds[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.BatchCallRevertedAt.selector,
                1
            )
        );
        sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_borrowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fuzzed);
    }

    function test_unit_borrowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fixedForSpeed);
    }

     function _test_borrowBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        bytes memory offerSignature = seller1CreateOffer(offer);

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        // invalid tokenIds.length
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = offer.collateralItem.tokenId;
        uint256[] memory tokenAmounts = new uint256[](1);

        vm.startPrank(borrower1);
        vm.expectRevert(INiftyApesErrors.InvalidInputLength.selector);
        sellerFinancing.borrowBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_borrowBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrowBatch_reverts_ifInvalidInputLengths(
            fuzzed
        );
    }

    function test_unit_borrowBatch_reverts_ifInvalidInputLengths()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_borrowBatch_reverts_ifInvalidInputLengths(
            fixedForSpeed
        );
    }
}
