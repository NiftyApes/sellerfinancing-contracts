pragma solidity ^0.8.18;

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
        address goerliRoyaltiesEngineAddress = 0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f;
        address goerliDelegateRegistryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;
        address goerliMultisigAddress = 0x213dE8CcA7C414C0DE08F456F9c4a2Abc4104028;

        vm.startBroadcast();

        // deploy and initialize implementation contracts
        sellerFinancingImplementation = new NiftyApesSellerFinancing();

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
        sellerFinancing.initialize(goerliRoyaltiesEngineAddress, goerliDelegateRegistryAddress);

        // pauseSanctions for Goerli as Chainalysis contact doesnt exists there
        sellerFinancing.pauseSanctions();

        // removed implementation transferOwnership because of empty constructor alleviating the need

        // change ownership of proxies
        IOwnership(address(sellerFinancing)).transferOwnership(goerliMultisigAddress);

        // change ownership of proxyAdmin
        sellerFinancingProxyAdmin.transferOwnership(goerliMultisigAddress);

        vm.stopBroadcast();
    }
}
