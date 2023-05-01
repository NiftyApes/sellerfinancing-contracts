pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "../src/interfaces/Ownership.sol";

import "../src/SellerFinancing.sol";

contract DeploySellerFinancingScript is Script {
    NiftyApesSellerFinancing sellerFinancing;

    function run() external {
        address goerliRoyaltiesEngineAddress = 0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f;
        address goerliDelegateRegistryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;

        address SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
        address GOERLI_WETH_ADDRESS = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

        vm.startBroadcast();

        // deploy and initialize implementation contracts
        sellerFinancing = new NiftyApesSellerFinancing();
        // empty constructor removed for goerli deploy so we dont have to deal with proxies
        sellerFinancing.initialize(
            goerliRoyaltiesEngineAddress,
            goerliDelegateRegistryAddress,
            SEAPORT_ADDRESS,
            GOERLI_WETH_ADDRESS
        );

        // pauseSanctions for Goerli as Chainalysis contact doesnt exists there
        sellerFinancing.pauseSanctions();

        vm.stopBroadcast();
    }
}
