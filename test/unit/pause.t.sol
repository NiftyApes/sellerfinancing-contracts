// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestPause is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_pause_simple_case() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.prank(owner);
        sellerFinancing.pause();

        vm.startPrank(buyer1);
        vm.expectRevert("Pausable: paused");
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1
        );

        vm.expectRevert("Pausable: paused");
        sellerFinancing.makePayment{ value: (1) }(
            offer.nftContractAddress,
            offer.nftId
        );

        vm.expectRevert("Pausable: paused");
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode("dummy order", bytes32(0))
        );

        vm.expectRevert("Pausable: paused");
        sellerFinancing.flashClaim(
            address(1),
            offer.nftContractAddress,
            offer.nftId,
            bytes("")
        );
        vm.stopPrank();

        vm.startPrank(seller1);
        vm.expectRevert("Pausable: paused");
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);

        vm.expectRevert("Pausable: paused");
        sellerFinancing.withdrawOfferSignature(offer, offerSignature);
        vm.stopPrank();
    }
}
