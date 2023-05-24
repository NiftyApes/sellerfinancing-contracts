// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingErrors.sol";

contract TestGetOfferSignatureStatus is
    Test,
    BaseTest,
    ISellerFinancingStructs,
    OffersLoansFixtures
{
    uint256 immutable SIGNER_PRIVATE_KEY_1 =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address immutable SIGNER_1 = 0x503408564C50b43208529faEf9bdf9794c015d52;

    function setUp() public override {
        super.setUp();
    }

    function test_unit_getOfferSignature_returnsTrue_whenWithdrawn() public {
        SellerFinancingOffer memory offer = SellerFinancingOffer({
            creator: seller1,
            nftContractAddress: address(0xB4FFCD625FefD541b77925c7A37A55f488bC69d9),
            nftId: 1,
            price: 1 ether,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(1657217355),
            collectionOfferLimit: 1
        });

        bytes32 offerHash = sellerFinancing.getSellerFinancingOfferHash(offer);

        bytes memory signature = sign(SIGNER_PRIVATE_KEY_1, offerHash);

        vm.startPrank(address(SIGNER_1));
        sellerFinancing.withdrawSellerFinancingOfferSignature(offer, signature);
        vm.stopPrank();

        assertEq(sellerFinancing.getOfferSignatureStatus(signature), true);
    }

    function test_unit_getOfferSignature_returnsTrue_whenUsed() public {
        SellerFinancingOffer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );

        bytes memory signature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            offer.nftId
        );
        vm.stopPrank();

        assertEq(sellerFinancing.getOfferSignatureStatus(signature), true);
    }

    function test_unit_getOfferSignature_returnsFalse_whenNotWithdrawnOrUsed() public {
        SellerFinancingOffer memory offer = SellerFinancingOffer({
            creator: seller1,
            nftContractAddress: address(0xB4FFCD625FefD541b77925c7A37A55f488bC69d9),
            nftId: 1,
            price: 1 ether,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(1657217355),
            collectionOfferLimit: 1
        });

        bytes32 offerHash = sellerFinancing.getSellerFinancingOfferHash(offer);

        bytes memory signature = sign(SIGNER_PRIVATE_KEY_1, offerHash);

        assertEq(sellerFinancing.getOfferSignatureStatus(signature), false);
    }
}
