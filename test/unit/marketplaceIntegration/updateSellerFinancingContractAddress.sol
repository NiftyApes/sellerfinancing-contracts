// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";

contract TestUpdateSellerFinancingContractAddress is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_marketPlace_updateSellerFinancingContractAddress_nonZeroAddress() public { 
        vm.prank(owner);
        marketplaceIntegration.updateSellerFinancingContractAddress(address(1));
        assertEq(marketplaceIntegration.sellerFinancingContractAddress(), address(1));
    }

    function test_unit_marketPlace_updateSellerFinancingContractAddress_reverts_if_zeroAddress() public { 
        vm.expectRevert(MarketplaceIntegration.ZeroAddress.selector);
        vm.prank(owner);
        marketplaceIntegration.updateSellerFinancingContractAddress(address(0));
    }
}
