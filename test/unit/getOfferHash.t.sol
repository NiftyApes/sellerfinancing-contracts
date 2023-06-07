// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestGetOfferHash is Test, INiftyApesStructs, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_getOfferHash() public {
        Offer memory offer = Offer({
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
            collectionOfferLimit: 1
        });

        bytes32 functionOfferHash = sellerFinancing.getOfferHash(offer);

        bytes32 expectedFunctionHash = 0x1931828706b2c87ed52a7279457e40b7c645f94098632948f94e7c34e61ed7e5;

        assertEq(functionOfferHash, expectedFunctionHash);
    }
}
