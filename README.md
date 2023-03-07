# <h1 align="center"> NiftyApes Seller Financing </h1>

## Getting Started

To run tests:

`forge test --optimize --fork-url https://eth-mainnet.g.alchemy.com/v2/jxUUn2DsYODlc68SEU_7eNGCn2hQ7b63`

To run deploy script:

1. supply env variable
2. `source .env`

Goerli Deploy

3. `forge script script/Goerli_Deploy_SellerFinancing.s.sol:DeploySellerFinancingScript --optimize --rpc-url $GOERLI_RPC_URL --private-key $GOERLI_PRIVATE_KEY --slow --broadcast`

Mainnet Deploy

4. `forge script script/Mainnet_Deploy_SellerFinancing.s.sol:DeploySellerFinancingScript --optimize --rpc-url $MAINNET_RPC_URL --private-key $MAINNET_BURNER_PRIVATE_KEY --slow --broadcast`
