# NiftyApesSellerFinancing
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/SellerFinancing.sol)

**Inherits:**
OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, EIP712Upgradeable, ERC721URIStorageUpgradeable, ERC721HolderUpgradeable, [ISellerFinancing](/src/interfaces/sellerFinancing/ISellerFinancing.sol/interface.ISellerFinancing.md)

**Author:**
captnseagraves (captnseagraves.eth)


## State Variables
### SANCTIONS_CONTRACT
*Internal constant address for the Chainalysis OFAC sanctions oracle*


```solidity
address private constant SANCTIONS_CONTRACT = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;
```


### MAX_BPS
The base value for fees in the protocol.


```solidity
uint256 private constant MAX_BPS = 10_000;
```


### _OFFER_TYPEHASH
*Constant typeHash for EIP-712 hashing of Offer struct
If the Offer struct shape changes, this will need to change as well.*


```solidity
bytes32 private constant _OFFER_TYPEHASH = keccak256(
    "Offer(uint128 price,uint128 downPaymentAmount,uint128 minimumPrincipalPerPeriod,uint256 nftId,address nftContractAddress,address creator,uint32 periodInterestRateBps,uint32 periodDuration,uint32 expiration)"
);
```


### loanNftNonce

```solidity
uint256 private loanNftNonce;
```


### royaltiesEngineContractAddress
*The stored address for the royalties engine*


```solidity
address private royaltiesEngineContractAddress;
```


### delegateRegistryContractAddress
*The stored address for the delegate registry contract*


```solidity
address public delegateRegistryContractAddress;
```


### seaportContractAddress
*The stored address for the seaport contract*


```solidity
address public seaportContractAddress;
```


### wethContractAddress
*The stored address for the weth contract*


```solidity
address public wethContractAddress;
```


### _sanctionsPause
*The status of sanctions checks*


```solidity
bool internal _sanctionsPause;
```


### _loans
*A mapping for a NFT to a loan .
The mapping has to be broken into two parts since an NFT is denominated by its address (first part)
and its nftId (second part) in our code base.*


```solidity
mapping(address => mapping(uint256 => Loan)) private _loans;
```


### _cancelledOrFinalized
*A mapping to mark a signature as used.
The mapping allows users to withdraw offers that they made by signature.*


```solidity
mapping(bytes => bool) private _cancelledOrFinalized;
```


### __gap
*This empty reserved space is put in place to allow future versions to add new
variables without shifting storage.*


```solidity
uint256[498] private __gap;
```


## Functions
### initialize

The initializer for the NiftyApes protocol.
NiftyApes is intended to be deployed behind a proxy and thus needs to initialize
its state outside of a constructor.


```solidity
function initialize(
    address newRoyaltiesEngineContractAddress,
    address newDelegateRegistryContractAddress,
    address newSeaportContractAddress,
    address newWethContractAddress
) public initializer;
```

### updateRoyaltiesEngineContractAddress

Updates royalty engine contract address to new address


```solidity
function updateRoyaltiesEngineContractAddress(address newRoyaltiesEngineContractAddress) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRoyaltiesEngineContractAddress`|`address`||


### updateDelegateRegistryContractAddress

Updates delegate registry contract address to new address


```solidity
function updateDelegateRegistryContractAddress(address newDelegateRegistryContractAddress) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDelegateRegistryContractAddress`|`address`|New delegate registry address|


### updateSeaportContractAddress

Updates seaport contract address to new address


```solidity
function updateSeaportContractAddress(address newSeaportContractAddress) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSeaportContractAddress`|`address`|New seaport address|


### updateWethContractAddress

Updates Weth contract address to new address


```solidity
function updateWethContractAddress(address newWethContractAddress) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newWethContractAddress`|`address`|New Weth contract address|


### pause


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

### pauseSanctions


```solidity
function pauseSanctions() external onlyOwner;
```

### unpauseSanctions


```solidity
function unpauseSanctions() external onlyOwner;
```

### getOfferHash

Returns an EIP712 standard compatible hash for a given offer.

*This hash can be signed to create a valid offer.*


```solidity
function getOfferHash(Offer memory offer) public view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offer`|`Offer`|The offer to compute the hash for|


### getOfferSigner

Returns the signer of an offer or throws an error.


```solidity
function getOfferSigner(Offer memory offer, bytes memory signature) public view override returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offer`|`Offer`|The offer to use for retrieving the signer|
|`signature`|`bytes`|The signature to use for retrieving the signer|


### getOfferSignatureStatus

Returns true if a given signature has been revoked otherwise false


```solidity
function getOfferSignatureStatus(bytes memory signature) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signature`|`bytes`|The signature to check|


### withdrawOfferSignature

Withdraw a given offer

*Calling this method allows users to withdraw a given offer by cancelling their signature on chain*


```solidity
function withdrawOfferSignature(Offer memory offer, bytes memory signature) external whenNotPaused;
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
function buyWithFinancing(Offer memory offer, bytes calldata signature, address buyer)
    external
    payable
    whenNotPaused
    nonReentrant;
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
function makePayment(address nftContractAddress, uint256 nftId) external payable whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`nftId`|`uint256`|The id of a specified NFT|


### _makePayment


```solidity
function _makePayment(address nftContractAddress, uint256 nftId, uint256 amountReceived)
    internal
    returns (address buyer);
```

### seizeAsset

Seize an asset from a defaulted loan.

*This function is only callable by the seller address*


```solidity
function seizeAsset(address nftContractAddress, uint256 nftId) external whenNotPaused nonReentrant;
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


```solidity
function instantSell(address nftContractAddress, uint256 nftId, uint256 minProfitAmount, bytes calldata data)
    external
    whenNotPaused
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nftContractAddress`|`address`|The address of the NFT collection|
|`nftId`|`uint256`|The id of a specified NFT|
|`minProfitAmount`|`uint256`|Minimum amount to accept for buyer's profit. Provides slippage control.|
|`data`|`bytes`|Order encoded as bytes|


### _sellAsset


```solidity
function _sellAsset(address nftContractAddress, uint256 nftId, uint256 minSaleAmount, bytes calldata data)
    private
    returns (uint256 saleAmountReceived);
```

### calculateMinimumPayment

Returns minimum payment required for the current period and current period interest

*This function calculates a sum of current and late payment values if applicable*


```solidity
function calculateMinimumPayment(Loan memory loan)
    public
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


### _validateSaleOrder


```solidity
function _validateSaleOrder(ISeaport.Order memory order, address nftContractAddress, uint256 nftId) internal view;
```

### _payRoyalties


```solidity
function _payRoyalties(address nftContractAddress, uint256 nftId, address from, uint256 amount)
    private
    returns (uint256 totalRoyaltiesPaid);
```

### _conditionalSendValue

*If "to" is a contract that doesn't accept ETH, send value back to "from" and continue
otherwise "to" could force a default by sending bearer nft to contract that does not accept ETH*


```solidity
function _conditionalSendValue(address to, address from, uint256 amount) internal;
```

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


### _getLoan


```solidity
function _getLoan(address nftContractAddress, uint256 nftId) private view returns (Loan storage);
```

### _createLoan


```solidity
function _createLoan(Loan storage loan, Offer memory offer, uint256 sellerNftId, uint256 buyerNftId, uint256 amount)
    internal;
```

### _transferNft


```solidity
function _transferNft(address nftContractAddress, uint256 nftId, address from, address to) internal;
```

### _currentTimestamp32


```solidity
function _currentTimestamp32() internal view returns (uint32);
```

### _requireIsNotSanctioned


```solidity
function _requireIsNotSanctioned(address addressToCheck) internal view;
```

### _requireAvailableSignature


```solidity
function _requireAvailableSignature(bytes memory signature) public view;
```

### _requireSignature65


```solidity
function _requireSignature65(bytes memory signature) public pure;
```

### _requireOfferNotExpired


```solidity
function _requireOfferNotExpired(Offer memory offer) internal view;
```

### _require721Owner


```solidity
function _require721Owner(address nftContractAddress, uint256 nftId, address owner) internal view;
```

### _requireSigner


```solidity
function _requireSigner(address signer, address expected) internal pure;
```

### _requireOpenLoan


```solidity
function _requireOpenLoan(Loan storage loan) internal view;
```

### _requireNftOwner


```solidity
function _requireNftOwner(Loan storage loan) internal view;
```

### _markSignatureUsed


```solidity
function _markSignatureUsed(Offer memory offer, bytes memory signature) internal;
```

### renounceOwnership


```solidity
function renounceOwnership() public override onlyOwner;
```

### receive

This contract needs to accept ETH from NFT Sale


```solidity
receive() external payable;
```

