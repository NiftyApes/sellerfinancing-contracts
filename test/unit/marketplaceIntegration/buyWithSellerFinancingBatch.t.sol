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

    function assertionsForExecutedLoan(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
        // loan auction exists
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                nftId
            ),
            true
        );
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), nftId).periodBeginTimestamp,
            block.timestamp
        );

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, nftId);
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.borrowerNftId), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.lenderNftId), seller1);
        
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId),
            IERC721MetadataUpgradeable(offer.item.token).tokenURI(nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId));

        // check loan struct values
        assertEq(loan.remainingPrincipal, offer.terms.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.terms.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.terms.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.terms.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.terms.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWithSellerFinancingMarketplaceBatch_simplest_case_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.item.identifier;
        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: offer.terms.downPaymentAmount + marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.item.identifier);

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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 8661;
        nftIds[1] = 6974;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.terms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftIds[0]);
        assertionsForExecutedLoan(offer, nftIds[1]);

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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceBefore = address(buyer1).balance;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 8661;
        nftIds[1] = 6974;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.terms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftIds[0]);
        // assert nftIds[1] is still owned by seller1
        assertEq(boredApeYachtClub.ownerOf(nftIds[1]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(offer.item.token, nftIds[1]);
        assertEq(loan.remainingPrincipal, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.terms.downPaymentAmount - marketplaceFee));
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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceBefore = address(buyer1).balance;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 8661;
        nftIds[1] = 6974;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.terms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftIds[1]);
        // assert nftIds[0] is still owned by seller1, because it didn't approve the NFT
        assertEq(boredApeYachtClub.ownerOf(nftIds[0]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(offer.item.token, nftIds[0]);
        assertEq(loan.remainingPrincipal, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.terms.downPaymentAmount - marketplaceFee));
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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceBefore = address(buyer1).balance;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 8661;
        nftIds[1] = 6974;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.terms.downPaymentAmount + 2 * marketplaceFee - 1}(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftIds[0]);
        // assert nftIds[1] is still owned by seller1
        assertEq(boredApeYachtClub.ownerOf(nftIds[1]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(offer.item.token, nftIds[1]);
        assertEq(loan.remainingPrincipal, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.terms.downPaymentAmount - marketplaceFee));
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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 8661;
        nftIds[1] = 6974;
        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.BuyWithSellerFinancingCallRevertedAt.selector,
                1
            )
        );
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.terms.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = 8661;
        nftIds[1] = 6974;
        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.InsufficientMsgValue.selector,
                2 * offer.terms.downPaymentAmount + 2 * marketplaceFee - 1,
                2 * offer.terms.downPaymentAmount + 2 * marketplaceFee
            )
        );
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: 2 * offer.terms.downPaymentAmount + 2 * marketplaceFee - 1}(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
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

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        Offer[] memory offers = new Offer[](2);
        offers[0] = offer;
        offers[1] = offer;
        bytes[] memory offerSignatures = new bytes[](2);
        offerSignatures[0] = offerSignature;
        offerSignatures[1] = offerSignature;
        // invalid nftIds.length
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.item.identifier;

        vm.startPrank(buyer1);
        vm.expectRevert(MarketplaceIntegration.InvalidInputLength.selector);
        marketplaceIntegration.buyWithSellerFinancingBatch{ value: offer.terms.downPaymentAmount * 2 + marketplaceFee * 2}(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
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
