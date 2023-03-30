# <h1 align="center"> NiftyApes Seller Financing </h1>

### High Level Description

The NiftyApes Seller Financing system enables the seller of an NFT to directly offer financing to a buyer without the need for 3rd party liquidity.

A general flow is described as:

1. The owner of an NFT may list it at a given price, down payment amount, interest rate per period, minimum principal per period (which determines the number of pay periods) and pay period duration.
2. Once executed, the NFT is entered into escrow in the NiftyApes Seller Financing contract, and a buyer can repay the loan in installments over time. During the loan a buyer can utilize their purchased NFT by using the Upon full repayment the buyer will receive NFT to their EOA or contract address.
3. If the buyer defaults, the seller keeps any payments made so far and can reclaim the NFT to keep or resell.
4. The system affords buyers the ability to make a late payment during a soft grace period that is one additional pay period in duration, so long as the seller has not already seized the NFT. This allows the buyer and seller the opportunity to communicate and negotitate a late payment without an automatic loss of investment by the buyer.

Here is simple diagram of the system:

![NiftyApes Seller Financing Flow Diagram](https://github.com/NiftyApes/sellerFinancing/blob/a17a94c3c4923e16f41b7e420fb6a610f607ac8b/NiftyApes_SellerFinancing_FlowDiagram.png)(

### Getting Started

To run tests:

`forge test --optimize --fork-url https://eth-mainnet.g.alchemy.com/v2/jxUUn2DsYODlc68SEU_7eNGCn2hQ7b63`

To run deploy script:

1. supply env variable
2. `source .env`
3. `forge script script/Goerli_Deploy_SellerFinancing.s.sol:DeploySellerFinancingScript --optimize --rpc-url $GOERLI_RPC_URL --private-key $GOERLI_PRIVATE_KEY --slow --broadcast`

### Contract verification

Easiest way is to use `forge` CLI. Documentation here: https://book.getfoundry.sh/reference/forge/forge-verify-contract

To verify implementation contract on Etherscan (need to include link to ECDSA library):

```
forge verify-contract <implementation contract address> NiftyApesSellerFinancing <Etherscan API key> --libraries "src/lib/ECDSABridge.sol:ECDSABridge:<ECDSABridge library address>" --watch
```

To verify ECDSABridge on Etherscan (if you don't do this Etherscan will say the implementation refers to an unverified library):

```
forge verify-contract <ECDSABridge library address> ECDSABridge <Etherscan API key> --watch
```

To verify proxy on Etherscan (probably won't need to do this again, as we probably won't deploy another proxy). Make sure `constructor-args.txt` exists and includes the three arguments passed to the proxy constructor, space-separated (see the example on https://book.getfoundry.sh/reference/forge/forge-verify-contract if you're having trouble here).

```
forge verify-contract <proxy contract address> TransparentUpgradeableProxy <Etherscan API Key> --constructor-args-path constructor-args.txt --watch
```
