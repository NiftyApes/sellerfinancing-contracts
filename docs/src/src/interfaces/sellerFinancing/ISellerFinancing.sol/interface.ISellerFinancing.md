# ISellerFinancing
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/sellerFinancing/ISellerFinancing.sol)

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
    address newDelegateRegistryAddress,
    address newSeaportContractAddress,
    address newWethContractAddress
) external;
```

