# ISellerFinancing
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/c32bcc4ddea85d7a717bf9d657523b95f48a4510/src/interfaces/sellerFinancing/ISellerFinancing.sol)

**Inherits:**
[ISellerFinancingAdmin](/src/interfaces/sellerFinancing/ISellerFinancingAdmin.sol/interface.ISellerFinancingAdmin.md), [ISellerFinancingEvents](/src/interfaces/sellerFinancing/ISellerFinancingEvents.sol/interface.ISellerFinancingEvents.md), [ISellerFinancingStructs](/src/interfaces/sellerFinancing/ISellerFinancingStructs.sol/interface.ISellerFinancingStructs.md), [ISellerFinancingErrors](/src/interfaces/sellerFinancing/ISellerFinancingErrors.sol/interface.ISellerFinancingErrors.md)


## Functions
### getOfferHash

Returns an EIP712 standard compatible hash for a given offer.

*This hash can be signed to create a valid offer.*


```solidity
function getOfferHash(Offer memory offer) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offer`|`Offer`|The offer to compute the hash for|


### getOfferSigner

Returns the signer of an offer or throws an error.


```solidity
function getOfferSigner(Offer memory offer, bytes memory signature) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offer`|`Offer`|The offer to use for retrieving the signer|
|`signature`|`bytes`|The signature to use for retrieving the signer|


### getOfferSignatureStatus

Returns true if a given signature has been revoked otherwise false


```solidity
function getOfferSignatureStatus(bytes calldata signature) external view returns (bool status);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signature`|`bytes`|The signature to check|


### withdrawOfferSignature

Withdraw a given offer

*Calling this method allows users to withdraw a given offer by cancelling their signature on chain*


```solidity
function withdrawOfferSignature(Offer memory offer, bytes calldata signature) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offer`|`Offer`|The offer to withdraw|
|`signature`|`bytes`|The signature of the offer|


### buyWithFinancing

Start a loan as buyer using a signed offer.

*buyer provided as param to allow for 3rd party marketplace integrations*


```solidity
function buyWithFinancing(Offer calldata offer, bytes memory signature, address buyer) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offer`|`Offer`|The details of the financing offer|
|`signature`|`bytes`|A signed offerHash|
|`buyer`|`address`|The address of the buyer|


### makePayment

Make a partial payment or full repayment of a loan.

*Any address may make a payment towards the loan.*


```solidity
function makePayment(address nftContractAddress, uint256 nftId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`nftId`|`uint256`|The id of a specified NFT|


### seizeAsset

Seize an asset from a defaulted loan.

*This function is only callable by the seller address*


```solidity
function seizeAsset(address nftContractAddress, uint256 nftId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`nftId`|`uint256`|The id of a specified NFT|


### instantSell

Sell the underlying nft and repay the loan using the proceeds of the sale.
Transfer remaining funds to the buyer

*This function is only callable by the buyer address*

*This function only supports valid Seaport orders*


```solidity
function instantSell(address nftContractAddress, uint256 nftId, uint256 minProfitAmount, bytes calldata data)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`nftId`|`uint256`|The id of a specified NFT|
|`minProfitAmount`|`uint256`|Minimum amount to accept for buyer's profit. Provides slippage control.|
|`data`|`bytes`|Order encoded as bytes|


### flashClaim

Allows an nftOwner to claim their nft and perform arbtrary actions (claim airdrops, vote in goverance, etc)
while maintaining their loan


```solidity
function flashClaim(address receiver, address nftContractAddress, uint256 nftId, bytes calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address of the external contract that will receive and return the nft|
|`nftContractAddress`|`address`|The address of the nft collection|
|`nftId`|`uint256`|The id of the specified nft|
|`data`|`bytes`|Arbitrary data structure, intended to contain user-defined parameters|


### getLoan

Returns a loan identified by a given nft.


```solidity
function getLoan(address nftContractAddress, uint256 nftId) external view returns (Loan memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`nftId`|`uint256`|The id of a specified NFT|


### balanceOf

Returns the total NFTs from a given collection owned by a user which has active loans in NiftyApes.


```solidity
function balanceOf(address owner, address nftContractAddress) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner|
|`nftContractAddress`|`address`|The address of the NFT collection|


### tokenOfOwnerByIndex

Returns an NFT token ID owned by `owner` at a given `index` of its token list.


```solidity
function tokenOfOwnerByIndex(address owner, address nftContractAddress, uint256 index) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the user|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`index`|`uint256`|The index of the owner's token list|


### calculateMinimumPayment

Returns minimum payment required for the current period and current period interest

*This function calculates a sum of current and late payment values if applicable*


```solidity
function calculateMinimumPayment(Loan memory loan)
    external
    view
    returns (uint256 minimumPayment, uint256 periodInterest);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`loan`|`Loan`|Loan struct details|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minimumPayment`|`uint256`|Minimum payment required for the current period|
|`periodInterest`|`uint256`|Unpaid interest amount for the current period|


### initialize


```solidity
function initialize(
    address newRoyaltiesEngineAddress,
    address newSeaportContractAddress,
    address newWethContractAddress
) external;
```

