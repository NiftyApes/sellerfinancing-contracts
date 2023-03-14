pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "../src/interfaces/Ownership.sol";

import "../src/SellerFinancing.sol";

contract DeploySellerFinancingScript is Script {
    NiftyApesSellerFinancing sellerFinancingImplementation;
    ProxyAdmin sellerFinancingProxyAdmin;
    TransparentUpgradeableProxy sellerFinancingProxy;
    ISellerFinancing sellerFinancing;

    function run() external {
        address mainnetRoyaltiesEngineAddress = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;
        address mainnetMultisigAddress = 0xbe9B799D066A51F77d353Fc72e832f3803789362;

        vm.startBroadcast();

        // deploy and initialize implementation contracts
        sellerFinancingImplementation = new NiftyApesSellerFinancing();
        sellerFinancingImplementation.initialize(address(0));

        // deploy proxy admins
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
        sellerFinancing.initialize(mainnetRoyaltiesEngineAddress);

        // change ownership of implementation contracts
        sellerFinancingImplementation.transferOwnership(mainnetMultisigAddress);

        // change ownership of proxies
        IOwnership(address(sellerFinancing)).transferOwnership(
            mainnetMultisigAddress
        );

        // change ownership of proxyAdmin
        sellerFinancingProxyAdmin.transferOwnership(mainnetMultisigAddress);

        vm.stopBroadcast();
    }
}
