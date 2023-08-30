// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUpdateProtocolFeeRecipient is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_updateProtocolFeeRecipient_nonZeroAddress() public { 
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeRecipient(owner);
        assertEq(sellerFinancing.protocolFeeRecipient(), owner);
    }

    function test_unit_updateProtocolFeeRecipient_reverts_if_zeroAddress() public { 
        vm.expectRevert(INiftyApesErrors.ZeroAddress.selector);
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeRecipient(address(0));
    }
}
