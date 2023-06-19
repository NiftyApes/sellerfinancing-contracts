// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";

contract TestSeizeAssetBatch is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function _assertionsForExecutedLoan(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
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
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        // loan exists
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.borrowerNftId), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.lenderNftId), seller1);
        
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _assertionsForClosedLoan(Offer memory offer, uint256 nftId, address expectedNftOwner) private {
        // expected address has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), expectedNftOwner);
        // require delegate.cash buyer delegation has been revoked
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                nftId
            ),
            false
        );
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        // loan doesn't exist anymore
        assertEq(
            loan.periodBeginTimestamp,
            0
        );
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), address(0));
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), address(0));
    }

    function _test_seizeAssetBatch_with_oneLoan(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        createOfferAndBuyWithSellerFinancing(offer);
        _assertionsForExecutedLoan(offer, offer.nftId);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.warp(loan.periodEndTimestamp + 1);

        address[] memory nftContractAddresses = new address[](1);
        nftContractAddresses[0] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.nftId;

        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.nftContractAddress, offer.nftId, loan);

        vm.startPrank(seller1);
        sellerFinancing.seizeAssetBatch(nftContractAddresses, nftIds);
        vm.stopPrank();

        _assertionsForClosedLoan(offer, nftIds[0], seller1);
    }

    function test_fuzz_seizeAssetBatch_with_oneLoan(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAssetBatch_with_oneLoan(fuzzed);
    }

    function test_unit_seizeAssetBatch_with_oneLoan() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAssetBatch_with_oneLoan(fixedForSpeed);
    }

    function _test_seizeAssetBatch_with_twoLoans(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.nftId = 0;
        uint256 nftId1 = 8661;
        uint256 nftId2 = 6974;

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1, nftId2);
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId2);
        vm.stopPrank();

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        _assertionsForExecutedLoan(offer, nftId1);
        _assertionsForExecutedLoan(offer, nftId2);

        Loan memory loan1 = sellerFinancing.getLoan(offer.nftContractAddress, nftId1);
        Loan memory loan2 = sellerFinancing.getLoan(offer.nftContractAddress, nftId2);

        vm.warp(loan1.periodEndTimestamp + 1);

        address[] memory nftContractAddresses = new address[](2);
        nftContractAddresses[0] = offer.nftContractAddress;
        nftContractAddresses[1] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId2;

        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.nftContractAddress, nftId1, loan1);
        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.nftContractAddress, nftId2, loan2);

        vm.startPrank(seller1);
        sellerFinancing.seizeAssetBatch(nftContractAddresses, nftIds);
        vm.stopPrank();

        _assertionsForClosedLoan(offer, nftIds[0], seller1);
        _assertionsForClosedLoan(offer, nftIds[1], seller1);
    }

    function test_fuzz_seizeAssetBatch_with_twoLoans(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAssetBatch_with_twoLoans(fuzzed);
    }

    function test_unit_seizeAssetBatch_with_twoLoans() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAssetBatch_with_twoLoans(fixedForSpeed);
    }

    function _test_seizeAssetBatch_reverts_if_anyOneSeize_reverts(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        createOfferAndBuyWithSellerFinancing(offer);
        _assertionsForExecutedLoan(offer, offer.nftId);

        uint256 nftId1 = 8661;
        uint256 nftId2 = 6974;

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        vm.warp(loan.periodEndTimestamp + 1);

        address[] memory nftContractAddresses = new address[](2);
        nftContractAddresses[0] = offer.nftContractAddress;
        nftContractAddresses[1] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId2;

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.seizeAssetBatch(nftContractAddresses, nftIds);
        vm.stopPrank();
    }

    function test_fuzz_seizeAssetBatch_reverts_if_anyOneSeize_reverts(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAssetBatch_reverts_if_anyOneSeize_reverts(fuzzed);
    }

    function test_unit_seizeAssetBatch_reverts_if_anyOneSeize_reverts() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAssetBatch_reverts_if_anyOneSeize_reverts(fixedForSpeed);
    }
}