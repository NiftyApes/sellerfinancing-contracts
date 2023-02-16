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

        bytes32 expectedFunctionHash = 0xdc9e2ea3c668ae9441d0986b6de891c023de78862783d13cf7d5d3e5485e0d42;

        assertEq(functionOfferHash, expectedFunctionHash);
    }
}
