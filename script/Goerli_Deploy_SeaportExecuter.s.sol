pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/externalExecuters/SeaportExecuter.sol";

contract DeploySeaportExecuterScript is Script {
    SeaportExecuter seaportExecuter;

    function run() external {
        address SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
        address GOERLI_WETH_ADDRESS = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

        vm.startBroadcast();

        // deploy implementation
        seaportExecuter = new SeaportExecuter(
            SEAPORT_ADDRESS,
            GOERLI_WETH_ADDRESS
        );

        // pauseSanctions for Goerli as Chainalysis contact doesnt exists there
        seaportExecuter.pauseSanctions();

        vm.stopBroadcast();
    }
}
