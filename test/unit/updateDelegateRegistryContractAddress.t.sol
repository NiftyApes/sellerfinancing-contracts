// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUpdateDelegateRegistryContractAddress is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_updateDelegateRegistryContractAddress_nonZeroAddress() public { 
        vm.prank(owner);
        sellerFinancing.updateDelegateRegistryContractAddress(address(1));
        assertEq(sellerFinancing.delegateRegistryContractAddress(), address(1));
    }

    function test_unit_updateDelegateRegistryContractAddress_reverts_if_zeroAddress() public { 
        vm.expectRevert(INiftyApesErrors.ZeroAddress.selector);
        vm.prank(owner);
        sellerFinancing.updateDelegateRegistryContractAddress(address(0));
    }
}
