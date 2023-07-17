// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestPause is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_pause_simple_case() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.prank(owner);
        sellerFinancing.pause();

        vm.startPrank(buyer1);
        vm.expectRevert("Pausable: paused");
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.nftId
        );

        vm.expectRevert("Pausable: paused");
        sellerFinancing.makePayment{ value: (1) }(offer.nftContractAddress, offer.nftId);

        vm.expectRevert("Pausable: paused");
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            0,
            abi.encode("dummy order", bytes32(0))
        );
        vm.stopPrank();

        address[] memory nftContractAddresses = new address[](1);
        nftContractAddresses[0] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.nftId;

        vm.startPrank(seller1);
        vm.expectRevert("Pausable: paused");
        sellerFinancing.seizeAsset(nftContractAddresses, nftIds);
    }
}
