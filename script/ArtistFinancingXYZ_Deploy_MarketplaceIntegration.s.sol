pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/marketplaceIntegration/MarketplaceIntegration.sol";
import "../src/interfaces/Ownership.sol";

contract DeployMarketplaceIntegrationScript is Script {
    MarketplaceIntegration marketplaceIntegration;

    function run() external {
        address mainnetMultisigAddress = 0xbe9B799D066A51F77d353Fc72e832f3803789362;

        // provide deployed sellerFinaningContractAddress here
        address sellerFinancingContractAddress = 0x1AD9752A86BBDB4b9B33Addc00e008D6E0308d03;
        // provide your desired fee recipient address here
        address marketplaceFeeRecipient = mainnetMultisigAddress;
        // provide your desired fee basis points for each transaction here
        uint256 marketplaceFeeBps = 0;

        vm.startBroadcast();

        // deploy implementation
        marketplaceIntegration = new MarketplaceIntegration(
            sellerFinancingContractAddress,
            marketplaceFeeRecipient,
            marketplaceFeeBps
        );

        // change ownership
        IOwnership(address(marketplaceIntegration)).transferOwnership(mainnetMultisigAddress);

        vm.stopBroadcast();
    }
}
