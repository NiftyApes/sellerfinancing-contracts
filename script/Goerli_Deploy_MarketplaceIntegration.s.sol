pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/marketplaceIntegration/MarketplaceIntegration.sol";

contract DeployMarketplaceIntegrationScript is Script {
    MarketplaceIntegration marketplaceIntegration;

    function run() external {
        // provide deployed sellerFinaningContractAddress here
        address sellerFinancingContractAddress = address(0);
        // provide your desired fee recipient address here
        address marketplaceFeeRecipient = address(0);
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

        vm.stopBroadcast();
    }
}
