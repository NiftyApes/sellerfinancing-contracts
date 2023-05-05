// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestBuyWithFinancingBatchMarketplace is Test, OffersLoansFixtures {
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

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.buyerNftId), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.sellerNftId), seller1);
        
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId));

        // check loan struct values
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWithFinancingMarketplaceBatch_simplest_case_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.nftId;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithFinancingBatch{ value: offer.downPaymentAmount + marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.nftId);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));
    }

    function test_fuzz_buyWithFinancingMarketplaceBatch_simplest_case_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_simplest_case_withOneOffer(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplaceBatch_simplest_case_withOneOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_simplest_case_withOneOffer(fixedForSpeed);
    }

    function _test_buyWithFinancingMarketplaceBatch_simplest_case_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
        marketplaceIntegration.buyWithFinancingBatch{ value: 2 * offer.downPaymentAmount + 2 * marketplaceFee }(
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

    function test_fuzz_buyWithFinancingMarketplaceBatch_simplest_case_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_simplest_case_withTwoOffers(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplaceBatch_simplest_case_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_simplest_case_withTwoOffers(fixedForSpeed);
    }

    function _test_buyWithFinancingMarketplaceBatch_partialExecution_withOneInvalidOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
        marketplaceIntegration.buyWithFinancingBatch{ value: 2 * offer.downPaymentAmount + 2 * marketplaceFee }(
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
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftIds[1]);
        assertEq(loan.remainingPrincipal, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.downPaymentAmount - marketplaceFee));
    }

    function test_fuzz_buyWithFinancingMarketplaceBatch_partialExecution_withOneInvalidOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_partialExecution_withOneInvalidOffer(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplaceBatch_partialExecution_withOneInvalidOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_partialExecution_withOneInvalidOffer(fixedForSpeed);
    }

    function _test_buyWithFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
        marketplaceIntegration.buyWithFinancingBatch{ value: 2 * offer.downPaymentAmount + 2 * marketplaceFee - 1}(
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
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftIds[1]);
        assertEq(loan.remainingPrincipal, 0);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;
        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert marketplace has gained fee for only one execution
        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.downPaymentAmount - marketplaceFee));
    }

    function test_fuzz_buyWithFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_partialExecution_withLessValueSentThanRequired(fixedForSpeed);
    }

    function _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifAnyOneBuyWithFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.collectionOfferLimit = 1;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
                MarketplaceIntegration.BuyWithFinancingCallRevertedAt.selector,
                1
            )
        );
        marketplaceIntegration.buyWithFinancingBatch{ value: 2 * offer.downPaymentAmount + 2 * marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifAnyOneBuyWithFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifAnyOneBuyWithFinancingCallFails(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifAnyOneBuyWithFinancingCallFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifAnyOneBuyWithFinancingCallFails(fixedForSpeed);
    }

    function _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

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
                2 * offer.downPaymentAmount + 2 * marketplaceFee - 1,
                2 * offer.downPaymentAmount + 2 * marketplaceFee
            )
        );
        marketplaceIntegration.buyWithFinancingBatch{ value: 2 * offer.downPaymentAmount + 2 * marketplaceFee - 1}(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fixedForSpeed);
    }

    function _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.InsufficientMsgValue.selector,
                offer.downPaymentAmount + marketplaceFee - 1,
                offer.downPaymentAmount + marketplaceFee
            )
        );
        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.nftId;
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithFinancingBatch{ value: offer.downPaymentAmount + marketplaceFee - 1}(
            offers,
            offerSignatures,
            buyer1,
            nftIds,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
            fuzzed
        );
    }

    function test_unit_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifValueSentLessThanDownpaymentPlusMarketFee()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplaceBatch_nonPartialExecution_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
            fixedForSpeed
        );
    }
}
