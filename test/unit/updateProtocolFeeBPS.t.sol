// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUpdateProtocolFeeBPS is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_updateProtocolFeeBPS_nonZeroValue() public { 
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(150);
        assertEq(sellerFinancing.protocolFeeBPS(), 150);
    }

    function test_unit_updateProtocolFeeBPS_does_not_revert_for_zeroValue() public { 
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(0);
        assertEq(sellerFinancing.protocolFeeBPS(), 0);
    }
}
