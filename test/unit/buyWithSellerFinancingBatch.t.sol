// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestBuyWithSellerFinancingBatch is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyWithSellerFinancingBatch_withETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;
        offer.marketplaceRecipients = new MarketplaceRecipient[](1);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        bytes memory offerSignature = seller1CreateOffer(offer);

        Offer[] memory offers = new Offer[](1);
        offers[0] = offer;
        bytes[] memory offerSignatures = new bytes[](1);
        offerSignatures[0] = offerSignature;
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenIds[0] = offer.collateralItem.tokenId;
        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        vm.startPrank(buyer1);
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanIds[0]);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingBatch_withETH_withOneOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_withETH_withOneOffer(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_withETH_withOneOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_withETH_withOneOffer(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_withETH_withTwoOffers(
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
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);
    }

    function test_fuzz_buyWithSellerFinancingBatch_withETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_withETH_withTwoOffers(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_withETH_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_withETH_withTwoOffers(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_withWETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
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
        weth.approve(address(sellerFinancing), 2 * offer.loanTerms.downPaymentAmount);
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);
    }

    function test_fuzz_buyWithSellerFinancingBatch_withWETH_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_withWETH_withTwoOffers(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_withWETH_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_withWETH_withTwoOffers(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_ERC1155_case_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.startPrank(seller1);
        erc1155Token.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

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
        tokenAmounts[0] = offer.collateralItem.amount;
        tokenAmounts[1] = offer.collateralItem.amount;
        vm.startPrank(buyer1);
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
        assertionsForExecutedLoanERC1155(offer, tokenIds[0], tokenAmounts[0], buyer1, loanIds[0], tokenAmounts[0]*2);
        assertionsForExecutedLoanERC1155(offer, tokenIds[1], tokenAmounts[1], buyer1, loanIds[1], tokenAmounts[0]*2);
    }

    function test_fuzz_buyWithSellerFinancingBatch_ERC1155_case_withTwoOffers(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_ERC1155_case_withTwoOffers(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_ERC1155_case_withTwoOffers() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_ERC1155_case_withTwoOffers(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_partialExecution_withSecondOfferInvalid(
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
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        // assert tokenIds[1] is still owned by seller1
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[1]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 buyer1BalanceAfter = address(buyer1).balance;
        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount));
    }

    function test_fuzz_buyWithSellerFinancingBatch_partialExecution_withSecondOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_partialExecution_withSecondOfferInvalid(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_partialExecution_withSecondOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_partialExecution_withSecondOfferInvalid(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_partialExecution_withFirstOfferInvalid(
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
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);
        // assert tokenIds[0] is still owned by seller1, because it didn't approve the NFT
        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[0]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert buyer balance is deduced from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount));
    }

    function test_fuzz_buyWithSellerFinancingBatch_partialExecution_withFirstOfferInvalid(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_partialExecution_withFirstOfferInvalid(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_partialExecution_withFirstOfferInvalid() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_partialExecution_withFirstOfferInvalid(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_partialExecution_withLessValueSentThanRequired(
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
        uint256[] memory loanIds = sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount - 1}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            true
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        // assert tokenIds[1] is still owned by seller1
        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(seller1));
        Loan memory loan = sellerFinancing.getLoan(loanIds[1]);
        assertEq(loan.loanTerms.principalAmount, 0);

        uint256 buyer1BalanceAfter = address(buyer1).balance;

        // assert buyer balance is deducted from one execution
        assertEq(buyer1BalanceAfter, (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount));
    }

    function test_fuzz_buyWithSellerFinancingBatch_partialExecution_withLessValueSentThanRequired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_partialExecution_withLessValueSentThanRequired(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_partialExecution_withLessValueSentThanRequired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_partialExecution_withLessValueSentThanRequired(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
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
        sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount }(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_nonPartialExecution_reverts_if_anyOne_BuyWithSellerFinancingCallFails(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
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
        sellerFinancing.buyWithSellerFinancingBatch{ value: 2 * offer.loanTerms.downPaymentAmount - 1}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingBatch_nonPartialExecution_reverts_ifInsufficientValueSent(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fuzzed);
    }

    function test_unit_buyWithSellerFinancingBatch_nonPartialExecution_reverts_ifInsufficientValueSent() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_nonPartialExecution_reverts_ifInsufficientValueSent(fixedForSpeed);
    }

     function _test_buyWithSellerFinancingBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
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
        sellerFinancing.buyWithSellerFinancingBatch{ value: offer.loanTerms.downPaymentAmount * 2}(
            offers,
            offerSignatures,
            buyer1,
            tokenIds,
            tokenAmounts,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingBatch_reverts_ifInvalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingBatch_reverts_ifInvalidInputLengths(
            fuzzed
        );
    }

    function test_unit_buyWithSellerFinancingBatch_reverts_ifInvalidInputLengths()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingBatch_reverts_ifInvalidInputLengths(
            fixedForSpeed
        );
    }
}