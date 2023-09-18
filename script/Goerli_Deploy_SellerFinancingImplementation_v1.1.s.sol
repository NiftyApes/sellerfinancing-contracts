pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "../src/interfaces/Ownership.sol";

import "../src/SellerFinancing.sol";

contract DeploySellerFinancingScript is Script {
    NiftyApesSellerFinancing sellerFinancing;

    function run() external {
        address goerliRoyaltiesEngineAddress = 0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f;
        address goerliDelegateRegistryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;

        vm.startBroadcast();

        // deploy and initialize implementation contract
        sellerFinancing = new NiftyApesSellerFinancing();

        sellerFinancing.initialize(goerliRoyaltiesEngineAddress, goerliDelegateRegistryAddress);

        sellerFinancing.updateProtocolInterestBPS(100);
        sellerFinancing.updateProtocolInterestRecipient(0xC1200B5147ba1a0348b8462D00d237016945Dfff);

        // pauseSanctions for Goerli as Chainalysis contact doesnt exists there
        sellerFinancing.pauseSanctions();

        vm.stopBroadcast();
    }
}
