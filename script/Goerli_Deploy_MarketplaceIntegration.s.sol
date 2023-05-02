pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/marketplaceIntegration/MarketplaceIntegration.sol";

contract DeployMarketplaceIntegrationScript is Script {
    MarketplaceIntegration marketplaceIntegration;

    function run() external {
        // provide deployed sellerFinaningContractAddress here
        address sellerFinancingContractAddress = 0xaa07875c41EF8C8648b09B313A2194539a23829a;
        // provide your desired fee recipient address here
        // set to NA Goerli Test Wallet
        address marketplaceFeeRecipient = 0xC1200B5147ba1a0348b8462D00d237016945Dfff;
        // provide your desired fee basis points for each transaction here
        // Set to 100 BPS in order to test fees
        uint256 marketplaceFeeBps = 100;

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
