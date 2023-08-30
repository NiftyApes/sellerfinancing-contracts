// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestBuyWith3rdPartyFinancingBatch is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyWith3rdPartyFinancingBatch_WETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, offer.collateralItem.tokenId);
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, offer.collateralItem.tokenId);

        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenIds[0] = offer.collateralItem.tokenId;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(order);
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount);
        uint256[] memory loanIds = sellerFinancing.buyWith3rdPartyFinancingBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            data,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanIds[0]);

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

    function test_fuzz_buyWith3rdPartyFinancingBatch_WETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancingBatch_WETH_withOneOffer(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancingBatch_WETH_withOneOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWith3rdPartyFinancingBatch_WETH_withOneOffer(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancingBatch_WETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.tokenId = 0;

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(lender1, 2*(offer.loanTerms.principalAmount));
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, 8661);
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, 6974);

        ISeaport.Order memory order1 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 8661);
        ISeaport.Order memory order2 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 6974);

        mintWeth(borrower1, 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        


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
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(order1);
        data[1] = abi.encode(order2);
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        uint256[] memory loanIds = sellerFinancing.buyWith3rdPartyFinancingBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            data,
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

        // borrower1 balance decreased by two times the token price minus offer.loanTerms.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancingBatch_WETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancingBatch_WETH_withTwoOffers(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancingBatch_WETH_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWith3rdPartyFinancingBatch_WETH_withTwoOffers(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancingBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;
        offer.collateralItem.tokenId = 0;

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(lender1, 2*(offer.loanTerms.principalAmount));
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, 8661);
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, 6974);

        ISeaport.Order memory order1 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 8661);
        ISeaport.Order memory order2 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 6974);

        mintWeth(borrower1, 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        
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
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(order1);
        data[1] = abi.encode(order2);
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        uint256[] memory loanIds = sellerFinancing.buyWith3rdPartyFinancingBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            data,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenIds[0], address(borrower1), loanIds[0]);

        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(seller2));
        Loan memory loan = sellerFinancing.getLoan(loanIds[1]);
        assertEq(loanIds[1], ~uint256(0));
        assertEq(loan.loanTerms.principalAmount, 0);

        // lender1 balance reduced by loan principal amount
        assertEq(
            weth.balanceOf(lender1),
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance decreased by token price minus offer.loanTerms.principalAmount
        assertEq(weth.balanceOf(borrower1), borrower1BalanceBefore - (order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancingBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancingBatch_partialExecution_withSecondOfferInvalid(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancingBatch_partialExecution_withSecondOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWith3rdPartyFinancingBatch_partialExecution_withSecondOfferInvalid(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancingBatch_partialExecution_withFirstOfferReverting(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.tokenId = 0;

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(lender1, 2*(offer.loanTerms.principalAmount));
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, 8661);
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, 6974);

        ISeaport.Order memory order1 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 8661);
        ISeaport.Order memory order2 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 6974);
        // transferring back the nft to make the first trx fail
        vm.prank(seller2);
        boredApeYachtClub.transferFrom(seller2, seller1, 8661);
        
        mintWeth(borrower1, 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        
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
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(order1);
        data[1] = abi.encode(order2);
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        uint256[] memory loanIds = sellerFinancing.buyWith3rdPartyFinancingBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            data,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, tokenIds[1], address(borrower1), loanIds[1]);

        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[0]);
        assertEq(loanIds[0], ~uint256(0));
        assertEq(loan.loanTerms.principalAmount, 0);

        // lender1 balance reduced by loan principal amount
        assertEq(
            weth.balanceOf(lender1),
            (lender1BalanceBefore - offer.loanTerms.principalAmount)
        );

        // borrower1 balance decreased by token price minus offer.loanTerms.principalAmount
        assertEq(weth.balanceOf(borrower1), borrower1BalanceBefore - (order2.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancingBatch_partialExecution_withFirstOfferReverting(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancingBatch_partialExecution_withFirstOfferReverting(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancingBatch_partialExecution_withFirstOfferReverting() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWith3rdPartyFinancingBatch_partialExecution_withFirstOfferReverting(fixedForSpeed);
    }

    function _test_buyWith3rdPartyFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;
        offer.collateralItem.tokenId = 0;

        bytes memory offerSignature = lender1CreateOffer(offer);
        mintWeth(lender1, 2*(offer.loanTerms.principalAmount));
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount*2);
        vm.stopPrank();

        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, 8661);
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, 6974);

        ISeaport.Order memory order1 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 8661);
        ISeaport.Order memory order2 = createAndValidateSeaportListingFromSeller2(WETH_ADDRESS, offer.loanTerms.principalAmount*2, 6974);

        mintWeth(borrower1, 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        
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
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(order1);
        data[1] = abi.encode(order2);
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), 2*(order1.parameters.consideration[0].endAmount - offer.loanTerms.principalAmount));
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.BatchCallRevertedAt.selector,
                1
            )
        );
        sellerFinancing.buyWith3rdPartyFinancingBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            data,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWith3rdPartyFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWith3rdPartyFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fixedForSpeed);
    }

     function _test_buyWith3rdPartyFinancingBatch_reverts_ifInvalidInputLengths(
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
        uint256[] memory tokenAmounts = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        vm.startPrank(borrower1);
        vm.expectRevert(INiftyApesErrors.InvalidInputLength.selector);
        sellerFinancing.buyWith3rdPartyFinancingBatch(
            offers,
            offerSignatures,
            borrower1,
            tokenIds,
            tokenAmounts,
            data,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWith3rdPartyFinancingBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancingBatch_reverts_ifInvalidInputLengths(
            fuzzed
        );
    }

    function test_unit_buyWith3rdPartyFinancingBatch_reverts_ifInvalidInputLengths()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWith3rdPartyFinancingBatch_reverts_ifInvalidInputLengths(
            fixedForSpeed
        );
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
}
