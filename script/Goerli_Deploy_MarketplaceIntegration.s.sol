pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/marketplaceIntegration/MarketplaceIntegration.sol";
import "../src/interfaces/Ownership.sol";

contract DeployMarketplaceIntegrationScript is Script {
    MarketplaceIntegration marketplaceIntegration;

    function run() external {
        address goerliMultisigAddress = 0x213dE8CcA7C414C0DE08F456F9c4a2Abc4104028;

        // provide deployed sellerFinaningContractAddress here
        address sellerFinancingContractAddress = 0x02C33A7baFf11FDd8A029F9380b9B7CD81534091;
        // provide your desired fee recipient address here
        address marketplaceFeeRecipient = goerliMultisigAddress;
        // provide your desired fee basis points for each transaction here
        uint256 marketplaceFeeBps = 0;

        vm.startBroadcast();

        // deploy implementation
        marketplaceIntegration = new MarketplaceIntegration(
            sellerFinancingContractAddress,
            marketplaceFeeRecipient,
            marketplaceFeeBps
        );

        // pauseSanctions for Goerli as Chainalysis contact doesnt exists there
        marketplaceIntegration.pauseSanctions();

        // change ownership
        IOwnership(address(marketplaceIntegration)).transferOwnership(goerliMultisigAddress);

        vm.stopBroadcast();
    }
}
