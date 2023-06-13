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
}
