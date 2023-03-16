# <h1 align="center"> NiftyApes Seller Financing </h1>

## Getting Started

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
