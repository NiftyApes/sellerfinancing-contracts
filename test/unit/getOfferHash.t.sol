// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestGetOfferHash is
    Test,
    ISellerFinancingStructs,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_getOfferHash() public {
        Offer memory offer = Offer({
            creator: seller1,
            nftContractAddress: address(
                0xB4FFCD625FefD541b77925c7A37A55f488bC69d9
            ),
            nftId: 1,
            price: 1 ether,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(1657217355)
        });

        bytes32 functionOfferHash = sellerFinancing.getOfferHash(offer);

        bytes32 expectedFunctionHash = 0x810911412828c4d5a4bf920bce5e82db3994a23ac57fc545a94d6a48168ce7c0;

        assertEq(functionOfferHash, expectedFunctionHash);
    }
}
