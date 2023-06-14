// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";

contract TestWithdrawAllOffers is
    Test,
    BaseTest,
    INiftyApesStructs,
    OffersLoansFixtures
{   
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
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId));

        // check loan struct values
        assertEq(loan.borrowerNftId, 0);
        assertEq(loan.lenderNftId, 1);
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function test_unit_withdrawAllOffers_invalidatesAllOffersCreated() public {
        Offer memory offer1 = Offer({
            creator: seller1,
            nftContractAddress: address(0xB4FFCD625FefD541b77925c7A37A55f488bC69d9),
            nftId: 1,
            offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
            principalAmount: 0.7 ether,
            isCollectionOffer: false,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(1657217355),
            collectionOfferLimit: 1,
            creatorOfferNonce: 0
        });

        Offer memory offer2 = Offer({
            creator: seller1,
            nftContractAddress: address(0xB4FFCD625FefD541b77925c7A37A55f488bC69d9),
            nftId: 1,
            offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
            principalAmount: 0.7 ether,
            isCollectionOffer: false,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(1657217355),
            collectionOfferLimit: 1,
            creatorOfferNonce: 0
        });
        
        bytes32 offerHash1 = sellerFinancing.getOfferHash(offer1);
        bytes memory signature1 = sign(seller1_private_key, offerHash1);

        bytes32 offerHash2 = sellerFinancing.getOfferHash(offer2);
        bytes memory signature2 = sign(seller1_private_key, offerHash2);

        vm.startPrank(address(seller1));
        sellerFinancing.withdrawAllOffers();
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOfferNonce.selector,
                0,
                1
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer1.downPaymentAmount }(
            offer1,
            signature1,
            buyer1,
            offer1.nftId
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOfferNonce.selector,
                0,
                1
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer2.downPaymentAmount }(
            offer2,
            signature2,
            buyer1,
            offer2.nftId
        );
        vm.stopPrank();
    }

    function test_unit_withdrawAllOffers_increments_currentUserOfferNonce() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        bytes memory signature1 = seller1CreateOffer(offer);

        vm.startPrank(address(seller1));
        sellerFinancing.withdrawAllOffers();
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOfferNonce.selector,
                0,
                1
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            signature1,
            buyer1,
            offer.nftId
        );
        vm.stopPrank();

        // increment the creatorOfferNonce and sign the offer again
        offer.creatorOfferNonce += 1;
        bytes memory signature2 = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            signature2,
            buyer1,
            offer.nftId
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.nftId);
    }
}
