pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/interfaces/maker/ISellerFinancingMaker.sol";
import "../src/interfaces/Ownership.sol";

import "../src/maker/SellerFinancingMaker.sol";

contract DeployMakerScript is Script {
    // provide deployed sellerFinaningContractAddress here
    address sellerFinancingContractAddress = address(0xf5Fa79D20d942a5210bF0FE9f5110102B8ECE955);

    SellerFinancingMaker makerImplementation;
    ProxyAdmin makerProxyAdmin;
    TransparentUpgradeableProxy makerProxy;
    ISellerFinancingMaker maker;

    // address SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    // address WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {

        address ownerAddress = 0x3c4AC95DA655DA25a77609907CBB8B0012b01fF6;
        address signerAddress = 0x3c4AC95DA655DA25a77609907CBB8B0012b01fF6;

        vm.startBroadcast();

        // deploy and initialize implementation contracts
        makerImplementation = new SellerFinancingMaker();
        makerImplementation.initialize(address(0));

        // deploy proxy admins
        makerProxyAdmin = new ProxyAdmin();

        // deploy proxies
        makerProxy = new TransparentUpgradeableProxy(
            address(makerImplementation),
            address(makerProxyAdmin),
            bytes("")
        );

        // declare interfaces
        maker = ISellerFinancingMaker(address(makerProxy));

        // initialize proxies
        maker.initialize(
            sellerFinancingContractAddress
        );

        // set signer
        maker.setApprovalForSigner(signerAddress, true);

        // pauseSanctions for Goerli as Chainalysis contact doesnt exists there
        // maker.pauseSanctions();

        // change ownership of implementation contracts
        makerImplementation.transferOwnership(ownerAddress);

        // change ownership of proxies
        IOwnership(address(maker)).transferOwnership(ownerAddress);

        // change ownership of proxyAdmin
        makerProxyAdmin.transferOwnership(ownerAddress);

        vm.stopBroadcast();
    }
}
