// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

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
        Offer memory offer1 = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        Offer memory offer2 = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);
        
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
        sellerFinancing.buyWithSellerFinancing{ value: offer1.loanTerms.downPaymentAmount }(
            offer1,
            signature1,
            buyer1,
            offer1.collateralItem.tokenId,
            offer1.collateralItem.amount
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOfferNonce.selector,
                0,
                1
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer2.loanTerms.downPaymentAmount }(
            offer2,
            signature2,
            buyer1,
            offer2.collateralItem.tokenId,
            offer2.collateralItem.amount
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
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature1,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        // increment the creatorOfferNonce and sign the offer again
        offer.creatorOfferNonce += 1;
        bytes memory signature2 = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature2,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);
    }
}
