// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "./utils/fixtures/OffersLoansFixtures.sol";
import "../src/interfaces/sellerFinancing/ISellerFinancing.sol";

contract TestCreateOffer is Test, ISellerFinancing {
    function setUp() public override {
        super.setUp();
    }

    function test_fuzz_cannot_createOffer_if_offer_expired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );

        offer.expiration = uint32(block.timestamp - 1);

        vm.expectRevert("00010");
        vm.startPrank(seller1);
        offers.createOffer(offer);
    }

    // function test_fuzz_cannot_createOffer_if_offer_duration_less_than_24_hours(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

    //     offer.duration = 1 days - 1 seconds;

    //     vm.expectRevert("00011");
    //     vm.startPrank(seller1);
    //     offers.createOffer(offer);
    // }

    // function test_fuzz_cannot_createOffer_not_NFT_owner(FuzzedOfferFields memory fuzzed)
    //     public
    //     validateFuzzedOfferFields(fuzzed)
    // {
    //     Offer memory offer = offerStructFromFields(fuzzed, defaultFixedBorrowerOfferFields);

    //     offer.nftId = 2;

    //     vm.expectRevert("00021");
    //     vm.startPrank(borrower1);
    //     offers.createOffer(offer);
    // }

    // function test_fuzz_cannot_createOffer_no_floor_terms_for_borrower_offer(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     Offer memory offer = offerStructFromFields(fuzzed, defaultFixedBorrowerOfferFields);

    //     offer.floorTerm = true;

    //     vm.expectRevert("00014");
    //     vm.startPrank(borrower1);
    //     offers.createOffer(offer);
    // }

    // function test_fuzz_cannot_createOffer_offerHash_already_exists(FuzzedOfferFields memory fuzzed)
    //     public
    //     validateFuzzedOfferFields(fuzzed)
    // {
    //     Offer memory offer = offerStructFromFields(fuzzed, defaultFixedBorrowerOfferFields);

    //     offer.floorTerm = false;

    //     vm.startPrank(borrower1);
    //     offers.createOffer(offer);

    //     vm.expectRevert("00046");
    //     offers.createOffer(offer);
    // }

    // function test_fuzz_cannot_createOffer_msgSenderDoesnNotEqualOfferCreator(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     Offer memory offer = offerStructFromFields(fuzzed, defaultFixedBorrowerOfferFields);

    //     offer.floorTerm = false;

    //     vm.startPrank(seller1);
    //     vm.expectRevert("00024");
    //     offers.createOffer(offer);
    // }
}
