// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";

contract TestGetOfferSignatureStatus is
    Test,
    BaseTest,
    INiftyApesStructs,
    OffersLoansFixtures
{
    uint256 immutable SIGNER_PRIVATE_KEY_1 =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address immutable SIGNER_1 = 0x503408564C50b43208529faEf9bdf9794c015d52;

    function setUp() public override {
        super.setUp();
    }

    function test_unit_getOfferSignature_returnsTrue_whenWithdrawn() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        bytes32 offerHash = sellerFinancing.getOfferHash(offer);

        bytes memory signature = sign(SIGNER_PRIVATE_KEY_1, offerHash);

        vm.startPrank(address(SIGNER_1));
        sellerFinancing.withdrawOfferSignature(offer, signature);
        vm.stopPrank();

        assertEq(sellerFinancing.getOfferSignatureStatus(signature), true);
    }

    function test_unit_getOfferSignature_returnsTrue_whenUsed() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );

        bytes memory signature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertEq(sellerFinancing.getOfferSignatureStatus(signature), true);
    }

    function test_unit_getOfferSignature_returnsFalse_whenNotWithdrawnOrUsed() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        bytes32 offerHash = sellerFinancing.getOfferHash(offer);

        bytes memory signature = sign(SIGNER_PRIVATE_KEY_1, offerHash);

        assertEq(sellerFinancing.getOfferSignatureStatus(signature), false);
    }
}
