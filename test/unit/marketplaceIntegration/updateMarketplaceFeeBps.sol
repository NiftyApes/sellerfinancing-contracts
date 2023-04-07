// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";

contract TestUpdateMarketplaceFeeBps is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_marketPlace_updateMarketplaceFeeBps_nonZeroAddress() public { 
        vm.prank(owner);
        marketplaceIntegration.updateMarketplaceFeeBps(1234);
        assertEq(marketplaceIntegration.marketplaceFeeBps(), 1234);
    }
}
