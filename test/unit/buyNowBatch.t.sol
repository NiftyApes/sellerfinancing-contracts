// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestBuyNowBatch is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyNowBatch_withETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        bytes memory offerSignature = seller1CreateOffer(offer);

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenIds[0] = offer.collateralItem.tokenId;
    
        vm.startPrank(buyer1);
        sellerFinancing.buyNowBatch{value: offer.loanTerms.downPaymentAmount}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        // buyer is the owner of the nft after the sale
        assertEq(boredApeYachtClub.ownerOf(offer.collateralItem.tokenId), buyer1);
    }

    function test_fuzz_buyNowBatch_withETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_withETH_withOneOffer(fuzzed);
    }

    function test_unit_buyNowBatch_withETH_withOneOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_withETH_withOneOffer(fixedForSpeed);
    }

    function _test_buyNowBatch_withETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

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
        vm.startPrank(buyer1);
        sellerFinancing.buyNowBatch{ value: 2 * offer.loanTerms.downPaymentAmount}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        // buyer is the owner of both the nft after
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), buyer1);
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), buyer1);
    }

    function test_fuzz_buyNowBatch_withETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_withETH_withTwoOffers(fuzzed);
    }

    function test_unit_buyNowBatch_withETH_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_withETH_withTwoOffers(fixedForSpeed);
    }

    function _test_buyNowBatch_withWETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        mintWeth(buyer1, 2*(offer.loanTerms.downPaymentAmount));

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
        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), 2 * offer.loanTerms.downPaymentAmount);
        sellerFinancing.buyNowBatch(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        // buyer is the owner of both the nft after
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), buyer1);
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), buyer1);
    }

    function test_fuzz_buyNowBatch_withWETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_withWETH_withTwoOffers(fuzzed);
    }

    function test_unit_buyNowBatch_withWETH_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_withWETH_withTwoOffers(fixedForSpeed);
    }

    function _test_buyNowBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        uint256[] memory tokenAmounts = new uint256[](2);
        vm.startPrank(buyer1);
        sellerFinancing.buyNowBatch{ value: 2 * offer.loanTerms.downPaymentAmount }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        // buyer is the owner of only first nft 
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), buyer1);
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), seller1);

        uint256 buyer1BalanceAfter = address(buyer1).balance;
        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount));
    }

    function test_fuzz_buyNowBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_partialExecution_withSecondOfferInvalid(fuzzed);
    }

    function test_unit_buyNowBatch_partialExecution_withSecondOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_partialExecution_withSecondOfferInvalid(fixedForSpeed);
    }

    function _test_buyNowBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        uint256[] memory tokenAmounts = new uint256[](2);
        vm.startPrank(buyer1);
        sellerFinancing.buyNowBatch{ value: 2 * offer.loanTerms.downPaymentAmount - 1}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        // buyer is the owner of only first nft 
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), buyer1);
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), seller1);

        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert buyer balance is deducted from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount));
    }

    function test_fuzz_buyNowBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_partialExecution_withLessValueSentThanRequired(fuzzed);
    }

    function test_unit_buyNowBatch_partialExecution_withLessValueSentThanRequired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_partialExecution_withLessValueSentThanRequired(fixedForSpeed);
    }

    function _test_buyNowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        uint256[] memory tokenAmounts = new uint256[](2);
        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.BatchCallRevertedAt.selector,
                1
            )
        );
        sellerFinancing.buyNowBatch{ value: 2 * offer.loanTerms.downPaymentAmount }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyNowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fuzzed);
    }

    function test_unit_buyNowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fixedForSpeed);
    }

    function _test_buyNowBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
        uint256[] memory tokenAmounts = new uint256[](2);
        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.BatchCallRevertedAt.selector,
                1
            )
        );
        sellerFinancing.buyNowBatch{ value: 2 * offer.loanTerms.downPaymentAmount - 1}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyNowBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fuzzed);
    }

    function test_unit_buyNowBatch_nonPartialExecution_reverts_ifInsufficientValueSent() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fixedForSpeed);
    }

     function _test_buyNowBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
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

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.InvalidInputLength.selector);
        sellerFinancing.buyNowBatch{ value: offer.loanTerms.downPaymentAmount * 2}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyNowBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNowBatch_reverts_ifInvalidInputLengths(
            fuzzed
        );
    }

    function test_unit_buyNowBatch_reverts_ifInvalidInputLengths()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNowBatch_reverts_ifInvalidInputLengths(
            fixedForSpeed
        );
    }
}
