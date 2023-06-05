// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestSellerFinancingInitialize is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_SellerFinancing_initialize() public {
        // we assert the already initalised values from deployments as the contract has already been initialized
        assertEq(sellerFinancing.seaportContractAddress(), SEAPORT_ADDRESS);
        assertEq(sellerFinancing.wethContractAddress(), WETH_ADDRESS);
        assertEq(sellerFinancing.royaltiesEngineContractAddress(), mainnetRoyaltiesEngineAddress);
        assertEq(sellerFinancing.delegateRegistryContractAddress(), mainnetDelegateRegistryAddress);
    }
}
