# <h1 align="center"> NiftyApes Seller Financing </h1>

## System Description

The NiftyApes Seller Financing system enables the seller of an NFT to directly offer financing to a buyer without the need for 3rd party liquidity.

A simple diagram of the system:

![NiftyApes Seller Financing Flow Diagram](https://github.com/NiftyApes/sellerFinancing/blob/44a6c4c831f04661b187744da080d6f7de6325cf/NiftyApes_SellerFinancing_FlowDiagram_1.png)

The flow and main actions of the system are described as:

#### List NFT With Financing

1. The owner of an NFT may list it at a given price, down payment amount, interest rate per period, minimum principal per period (which determines the number of pay periods) and pay period duration by signing a properly formed offer struct and supplying it to the NiftyApes API. An owner can also provide a nftId of ~uint256(0) and a collectionOfferLimit value as a way to make a collection financing offer and support mint financing.

#### Execute A Purchase

2. When a buyer executes a sale by supplying the signed financing offer to the `buyWithSellerFinancing()` function the NFT is entered into escrow in the NiftyApes Seller Financing contract and a loan is initiated.

#### Utilize The Purchased NFT

3. During the loan a buyer can utilize their purchased NFT on an platform, protocol, or service supported by delegate.cash.

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

## Marketplace Integration

The intention is for the main usage of the NiftyApes Seller Financing protocol to be through the NiftyApes SDK. This SDK will be integrated with 3rd party marketplace dapps. In order to serve this use case we have provided a `MarketplaceIntegration` contract in addition to the core Seller Financing protocol. The integration contract allows an owner to specify a `marketplaceFeeBps` and `marketplaceFeeRecipient`, and allows a user to call the `buyWithSellerFinancing()` function which passes the calculated marketplace fee to the `marketplaceFeeRecipient` upon execution.

## Use Cases

So far, we have identified 4 major use cases for the NiftyApes Seller Financing Protocol and the NiftyApes SDK. Each of these use cases may have a different frontend UI but are served by the same smart contract functionality.

#### Mint Financing

1. Creators can offer financing on a lazy mint of their collection. Creators can sell more NFTs, more quickly, for more money. Buyers have the ability to buy more NFTs with the same amount of money. Buyers can sell the NFTs they have minted at any time if the proceeds of the sale cover the remaining principal and interest of the loan.

#### Artist Financing

2. Similarly, as in the traditional art world via entities like Sotheby's or Christie's, artists can offer financing on a 1/1 or limited piece drop. Artists can sell more art, more quickly, for more money. In this case, perhaps a major draw is that buyers have the ability to spend more on art with the same initial capital. This might result in higher sale prices for artists and larger collections for buyers. It may also provide a more consistent stream of income for artists rather than the lump sum payments they commonly have in todays digital art markets.

#### Secondary Markets

3. Sellers can offer financing as a way to achieve a higher sale price they may be targeting, as well as selling more NFTs, more quickly, for more money. Buyers can purchase an NFT in installments over time while still accessing the on-chain and IRL benefits of the NFT such as discord access, air drops, voiting in governance, and attending IRL events.

#### Short Term Trading

4. Sellers can offer short term loans in collections with high volume, sufficient bid depth, and positive price action, locking in a profitable trade via a price mark up each time a buyer fully closes their loan (whether the buyer makes a profit or not). Sellers are significantly hedged against default by the amount of down payment they require to service the loan and by a buyer's incentive to cut losses. Buyers can make more money by buying multiple short term loans for trades they would otherwise already be making. If a loan requires a 20% down payment and a 1% price mark up a buyer can buy 5 NFTs with the same capital they would have previously used to buy 1 NFT. If the price in this example goes up by 5% the buyer would make a 20% gain rather than a 5% gain made on the same capital previously.

## 🚨🚨🚨 Protocol Warnings 🚨🚨🚨

#### Making Payments and Receving NFTs As A Contract

1. The NiftyApes Seller Financing protocol abides by the ERC721 `safeTransferFrom()` pattern. All contracts interacting with the system must implement `onERC721Receive()` in compliance with ERC721 if they expect to receive NFTS. For example, if the buyer is a contract that has not implemented `onERC721Receive()` it will be able to call `makePayment()` and make payments on a seller financing loan but will NOT be able to fully repay and receive the NFT at the close of the loan. This may result in a default and asset seizure by the seller.

#### Accepting Payments As A Contract

2. Any contract holding a seller ticket and expecting to receive payments MUST be able to recieve ETH. If the holder of a seller ticket cannot receive ETH at the time of a loan payment by a buyer they will be slashed for the value of the payment. All payment value sent will be deducted from the remaining loan principal, possibly closing the loan, no funds will be sent to the holder of the seller ticket (as the actor cannot recieve ETH), and all funds will be returned to the msg.sender.

This dynamic prevents a nefarious seller from sending the seller ticket to a contract that cannot accept ETH, barring the buyer from making a payment in earnest, and forcing an eventual default whereby the seller could seize the underlying NFT.

#### Privileged Roles and Ownership

3. The owner of the Seller Financing contract has the ability to call these functions which modify some limited aspects of state and state addresses:

   - updateRoyaltiesEngineContractAddress()
   - updateDelegateRegistryContractAddress()
   - updateSeaportContractAddress()
   - updateWethContractAddress()
   - pause(), unpause()
   - pauseSanctions(), unpauseSanctions()

4. The owner of any Marketplace Integration contract has the ability to call these functions which modify some limited aspects of state and state addresses:
   - updateSellerFinancingContractAddress()
   - updateMarketplaceFeeRecipient()
   - updateMarketplaceFeeBps()
   - pause(), unpause()
   - pauseSanctions(), unpauseSanctions()

#### Limited Protocol and Loan Time Horizon

5. The NiftyApes Seller Financing Protocol v1.0 utilizes `uint32` timestamps throughout the protocol. This has been done to reduce the compile time contract size and runtime gas useage. This means that the protocol will cease to function and no loans can go beyond January 19, 2038 at 3:14:07 UTC, roughly 15 years from the time of writing. The intention is for this first version of the protocol to be phased out in the future in favor of a second version that does support loans beyond this January 19, 2038 at 3:14:07 UTC.

#### `withdrawSellerFinancingOfferSignature()` Vulnerable to Front-Running

6. `withdrawSellerFinancingOfferSignature()` is vulnerable to front-running. If a seller submits a transaction calling `withdrawSellerFinancingOfferSignature()` to the mempool on an undesirable existing offer, a savvy witnesser could see this and buy the offer prior to the cancellation. This can result in sellers being forced to finance NFTs on Offers that they don't intend to keep or are no longer desirable due to market conditions. We suggest utilizing a short expiration for offers and resubmitting offers often or submitting a `withdrawSellerFinancingOfferSignature()` transaction via a service such as Flashbots as a way to mitigate this issue as well as market volatility and foster price discovery.

#### Seller Cannot Make The Exact Same Offer Twice

7. If an offer's signature gets used once or has been previously canceled, the seller will be unable to make the same offer again. We suggest simply incrementing the expiration timestamp by one second to mitigate this issue.

#### Excessive Ether Funds are Refunded to the Buyer Rather than Msg.sender

8. In `buyWithSellerFinancing()`, if `msg.value` exceeds `offer.downPaymentAmount()`, the refund is issued to the buyer ticket holder rather than the `msg.sender`. This is done so that buyers receive their refund for purchases made through the MarketplaceIntegration contract, which is deployed by a 3rd party and collects a marketplace fee before making an external call to SellerFinancing.buyWithSellerFinancing(). Users interacting directly with the SellerFinancing contract should be aware that excessive payments are sent directly to the buyer ticket holder.

#### Purchase of Defaulted Buyer Tickets

9. Buyer and seller tickets are transferable at any time, even after a loan is in default. A purchaser of a buyer ticket should be aware of the state of the debt obligation they are purchasing before executing any transaction, as it may be in default and open to immeadiate asset seizure.

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
