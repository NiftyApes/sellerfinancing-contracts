// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/erc721MintFinancing/ERC721MintFinancing.sol";

contract TestUpdateSellerFinancingContractAddress is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_erc721MintFinancing_updateSellerFinancingContractAddress_nonZeroAddress()
        public
    {
        vm.prank(seller1);
        erc721MintFinancing.updateSellerFinancingContractAddress(address(1));
        assertEq(erc721MintFinancing.sellerFinancingContractAddress(), address(1));
    }

    function test_unit_erc721MintFinancing_updateSellerFinancingContractAddress_reverts_if_zeroAddress()
        public
    {
        vm.expectRevert(ERC721MintFinancing.ZeroAddress.selector);
        vm.prank(seller1);
        erc721MintFinancing.updateSellerFinancingContractAddress(address(0));
    }
}
