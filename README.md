# <h1 align="center"> NiftyApes Seller Financing </h1>

## System Description

The NiftyApes Seller Financing system enables the seller of an NFT to directly offer financing to a buyer without the need for 3rd party liquidity.

A simple diagram of the system:

![NiftyApes Seller Financing Flow Diagram](https://github.com/NiftyApes/sellerFinancing/blob/44a6c4c831f04661b187744da080d6f7de6325cf/NiftyApes_SellerFinancing_FlowDiagram_1.png)

The flow and main actions of the system are described as:

#### List NFT With Financing

1. The owner of an NFT may list it at a given price, down payment amount, interest rate per period, minimum principal per period (which determines the number of pay periods) and pay period duration by signing a properly formed offer sturct and supplying it to the NiftyApes API.

#### Execute A Purchase

2. When a buyer executes a sale by supplying the signed financing offer to the `buyWithFinancing()` function the NFT is entered into escrow in the NiftyApes Seller Financing contract and a loan is initiated.

#### Utilize The Purchased NFT

3. During the loan a buyer can utilize their purchased NFT by calling the `balanceOf()` and `tokenOfOwnerById()` functions to read ownership of specified nftContractAddress and nftId, or the `flashClaim()` function to conduct any arbitrary onchain action using the NFT.

#### Sell At Any Time

4. At any time during the loan or soft grace period, a buyer can accept a valid Seaport bid order for the NFT using the `instantSell()` function so long as the proceeds of the sale cover the remaining principal of the loan plus any relevant interest. This action will pay any remaining principal and interest due on the loan to the seller, transfer the remaining value to the buyer, and transfer the underlying NFT to the new buyer.

#### Buyer And Seller Tickets

5. In addition, both buyer and seller are minted an NFT loan ticket that represents ownership of their side of the loan and which they can transfer or sell to any other address. This allows another actor to assume the debt obligation or stream of revenue of the loan.

#### Make A Payment and Repay Loan

6. A buyer can repay the loan in installments over time, or in full at any time, using the `makePayment()` function. Upon full repayment the buyer will receive the purchased NFT to their EOA or contract address and both buyer and seller loan tickets are burned.

#### Seize A Defaulted Asset

7. If a buyer defaults (failing to make a payment before the end of a pay period), the seller can call the `seizeAsset()` function, thus keeping any payments made so far and reclaiming the NFT to keep or resell. Upon asset seizure both buyer and seller loan tickets are burned.

#### Late Payments

8. The system affords buyers the ability to make a late payment during a soft grace period that is one additional pay period in duration, so long as the seller has not already seized the NFT. This allows the buyer and seller the opportunity to communicate and negotitate a late payment without an automatic loss of investment by the buyer.

## Getting Started

To run tests:

`forge test --optimize --fork-url https://eth-mainnet.g.alchemy.com/v2/jxUUn2DsYODlc68SEU_7eNGCn2hQ7b63`

To run deploy script:

1. supply required env variables
2. `source .env`
3. `forge script script/Goerli_Deploy_SellerFinancing.s.sol:DeploySellerFinancingScript --optimize --rpc-url $GOERLI_RPC_URL --private-key $GOERLI_PRIVATE_KEY --slow --broadcast --verify`

### Contract verification

**In the case verification fails on deployment**

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
