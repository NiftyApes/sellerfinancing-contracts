// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../../../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "./FlashClaimReceivers/FlashClaimReceiverTestHappy.sol";
import "./FlashClaimReceivers/FlashClaimReceiverTestNoReturn.sol";
import "./FlashClaimReceivers/FlashClaimReceiverTestReturnsFalse.sol";
import "../../../src/SellerFinancing.sol";
import "./NFTFixtures.sol";

import "forge-std/Test.sol";

// deploy & initializes SellerFinancing contracts
contract SellerFinancingDeployment is Test, NFTFixtures {
    ProxyAdmin sellerFinancingProxyAdmin;

    NiftyApesSellerFinancing sellerFinancingImplementation;
    TransparentUpgradeableProxy sellerFinancingProxy;
    ISellerFinancing sellerFinancing;

    FlashClaimReceiverBaseHappy flashClaimReceiverHappy;
    FlashClaimReceiverBaseNoReturn flashClaimReceiverNoReturn;
    FlashClaimReceiverBaseReturnsFalse flashClaimReceiverReturnsFalse;

    address SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address SEAPORT_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public virtual override {
        address mainnetRoyaltiesEngineAddress = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;

        super.setUp();

        vm.startPrank(owner);

        flashClaimReceiverHappy = new FlashClaimReceiverBaseHappy();
        flashClaimReceiverNoReturn = new FlashClaimReceiverBaseNoReturn();
        flashClaimReceiverReturnsFalse = new FlashClaimReceiverBaseReturnsFalse();

        sellerFinancingImplementation = new NiftyApesSellerFinancing();
        sellerFinancingImplementation.initialize(
            address(0),
            address(0),
            address(0)
        );

        // deploy proxy admin
        sellerFinancingProxyAdmin = new ProxyAdmin();

        // deploy proxies
        sellerFinancingProxy = new TransparentUpgradeableProxy(
            address(sellerFinancingImplementation),
            address(sellerFinancingProxyAdmin),
            bytes("")
        );

        // declare interfaces
        sellerFinancing = ISellerFinancing(address(sellerFinancingProxy));

        // initialize proxies
        sellerFinancing.initialize(
            mainnetRoyaltiesEngineAddress,
            SEAPORT_ADDRESS,
            WETH_ADDRESS
        );

        flashClaimReceiverHappy.updateFlashClaimContractAddress(
            address(sellerFinancing)
        );

        vm.stopPrank();

        vm.label(address(0), "NULL !!!!! ");
    }
}
