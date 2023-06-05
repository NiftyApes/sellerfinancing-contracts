// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestGetOfferHash is Test, ISellerFinancingStructs, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_getOfferHash() public {
        Offer memory offer = Offer({
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

        bytes32 functionOfferHash = sellerFinancing.getOfferHash(offer);

        bytes32 expectedFunctionHash = 0x4898491da424488aea526b4b0923e22b79885f4ed79a76331ec4866d53a14705;

        assertEq(functionOfferHash, expectedFunctionHash);
    }
}
