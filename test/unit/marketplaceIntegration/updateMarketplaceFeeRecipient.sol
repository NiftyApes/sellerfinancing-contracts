// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";

contract TestUpdateMarketplaceFeeRecipient is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_marketPlace_updateMarketplaceFeeRecipient_nonZeroAddress() public { 
        vm.prank(owner);
        marketplaceIntegration.updateMarketplaceFeeRecipient(address(1));
        assertEq(marketplaceIntegration.marketplaceFeeRecipient(), address(1));
    }

    function test_unit_marketPlace_updateMarketplaceFeeRecipient_reverts_if_zeroAddress() public { 
        vm.expectRevert(MarketplaceIntegration.ZeroAddress.selector);
        vm.prank(owner);
        marketplaceIntegration.updateMarketplaceFeeRecipient(address(0));
    }
}
