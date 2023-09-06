// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUpdateSeaportContractAddress is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_updateSeaportContractAddress_nonZeroAddress() public { 
        vm.prank(owner);
        sellerFinancing.updateSeaportContractAddress(address(1));
        assertEq(sellerFinancing.seaportContractAddress(), address(1));
    }

    function test_unit_updateSeaportContractAddress_reverts_if_zeroAddress() public { 
        vm.expectRevert(INiftyApesErrors.ZeroAddress.selector);
        vm.prank(owner);
        sellerFinancing.updateSeaportContractAddress(address(0));
    }
}
