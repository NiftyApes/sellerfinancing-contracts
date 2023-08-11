// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestBuyWithSellerFinancingBatchMarketplace is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenIds[0] = offer.collateralItem.tokenId;
        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        vm.startPrank(buyer1);
        uint256[] memory loanIds = marketplaceIntegration.buyWithSellerFinancingBatch{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanIds[0]);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_simplest_case_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withOneOffer(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_simplest_case_withOneOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withOneOffer(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

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
        uint256[] memory loanIds = marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + 2 * marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_simplest_case_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withTwoOffers(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_simplest_case_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withTwoOffers(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
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
        uint256[] memory loanIds = marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        // assert tokenIds[1] is still owned by seller1
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[1]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount - marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withSecondOfferInvalid(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_partialExecution_withSecondOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withSecondOfferInvalid(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withFirstOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
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
        uint256[] memory tokenAmounts = new uint256[](1);
        vm.startPrank(buyer1);
        uint256[] memory loanIds = marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);
        // assert tokenIds[0] is still owned by seller1, because it didn't approve the NFT
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[0]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount - marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_partialExecution_withFirstOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withFirstOfferInvalid(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_partialExecution_withFirstOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withFirstOfferInvalid(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
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
        uint256[] memory loanIds = marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee - 1}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        // assert tokenIds[1] is still owned by seller1
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[1]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deducted from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount - marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
                MarketplaceIntegration.BuyWithSellerFinancingCallRevertedAt.selector,
                1
            )
        );
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
                MarketplaceIntegration.InsufficientMsgValue.selector,
                2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee - 1,
                2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee
            )
        );
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount + 2 * marketplaceFee - 1}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fixedForSpeed);
    }

     function _test_buyWithSellerFinancingMarketplaceBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
        vm.expectRevert(MarketplaceIntegration.InvalidInputLength.selector);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: offer.loanTerms.downPaymentAmount * 2 + marketplaceFee * 2}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            // tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingMarketplaceBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplaceBatch_reverts_ifInvalidInputLengths(
            fuzzed
        );
    }

    function test_unit_buyWithSellerFinancingMarketplaceBatch_reverts_ifInvalidInputLengths()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplaceBatch_reverts_ifInvalidInputLengths(
            fixedForSpeed
        );
    }
}
