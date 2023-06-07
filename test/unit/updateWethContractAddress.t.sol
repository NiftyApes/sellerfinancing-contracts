// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUpdateWethContractAddress is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_updateWethContractAddress_nonZeroAddress() public { 
        vm.prank(owner);
        sellerFinancing.updateWethContractAddress(address(1));
        assertEq(sellerFinancing.wethContractAddress(), address(1));
    }

    function test_unit_updateWethContractAddress_reverts_if_zeroAddress() public { 
        vm.expectRevert(INiftyApesErrors.ZeroAddress.selector);
        vm.prank(owner);
        sellerFinancing.updateWethContractAddress(address(0));
    }
}
