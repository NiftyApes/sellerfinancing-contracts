// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUpdateRoyaltiesEngineContractAddress is
    Test,
    BaseTest,
    OffersLoansFixtures
{
    function setUp() public override {
        super.setUp();
    }

    function test_unit_updateRoyaltiesEngineContractAddress_nonZeroAddress() public { 
        vm.prank(owner);
        sellerFinancing.updateRoyaltiesEngineContractAddress(address(1));
        assertEq(sellerFinancing.royaltiesEngineContractAddress(), address(1));
    }

    function test_unit_updateRoyaltiesEngineContractAddress_reverts_if_zeroAddress() public { 
        vm.expectRevert(INiftyApesErrors.ZeroAddress.selector);
        vm.prank(owner);
        sellerFinancing.updateRoyaltiesEngineContractAddress(address(0));
    }
}
