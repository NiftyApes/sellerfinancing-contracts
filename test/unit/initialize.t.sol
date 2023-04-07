// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestSellerFinancingInitialize is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_SellerFinancing_initialize() public {
        TransparentUpgradeableProxy sellerFinancingProxyTest;
        ISellerFinancing sellerFinancingTest;

        // deploy proxies
        sellerFinancingProxyTest = new TransparentUpgradeableProxy(
            address(sellerFinancingImplementation),
            address(sellerFinancingProxyAdmin),
            bytes("")
        );

        // declare interfaces
        sellerFinancingTest = ISellerFinancing(address(sellerFinancingProxyTest));

        // initialize proxies
        sellerFinancingTest.initialize(
            mainnetRoyaltiesEngineAddress,
            mainnetDelegateRegistryAddress,
            SEAPORT_ADDRESS,
            WETH_ADDRESS
        );
        assertEq(sellerFinancingTest.seaportContractAddress(), SEAPORT_ADDRESS);
        assertEq(sellerFinancingTest.wethContractAddress(), WETH_ADDRESS);
    }
}
