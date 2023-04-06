# MarketplaceIntegration
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/marketplaceIntegration/MarketplaceIntegration.sol)

**Inherits:**
Ownable, Pausable

**Author:**
zishansami102 (zishansami.eth)


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


### _sanctionsPause
*The status of sanctions checks*


```solidity
bool internal _sanctionsPause;
```


### marketplaceFeeBps

```solidity
uint256 public marketplaceFeeBps;
```


### marketplaceFeeRecipient

```solidity
address payable public marketplaceFeeRecipient;
```


### sellerFinancingContractAddress

```solidity
address public sellerFinancingContractAddress;
```


## Functions
### constructor


```solidity
constructor(address _sellerFinancingContractAddress, address _marketplaceFeeRecipient, uint256 _marketplaceFeeBps);
```

### updateSellerFinancingContractAddress


```solidity
function updateSellerFinancingContractAddress(address newSellerFinancingContractAddress) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSellerFinancingContractAddress`|`address`|New address for SellerFinancing contract|


### updateMarketplaceFeeRecipient


```solidity
function updateMarketplaceFeeRecipient(address newMarketplaceFeeRecipient) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMarketplaceFeeRecipient`|`address`|New address for MarketplaceFeeRecipient|


### updateMarketplaceFeeBps


```solidity
function updateMarketplaceFeeBps(uint256 newMarketplaceFeeBps) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMarketplaceFeeBps`|`uint256`|New value for marketplaceFeeBps|


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

### buyWithFinancing


```solidity
function buyWithFinancing(ISellerFinancing.Offer memory offer, bytes calldata signature, address buyer)
    external
    payable
    whenNotPaused;
```

### _requireNonZeroAddress


```solidity
function _requireNonZeroAddress(address given) internal pure;
```

### _requireIsNotSanctioned


```solidity
function _requireIsNotSanctioned(address addressToCheck) internal view;
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### InsufficientMsgValue

```solidity
error InsufficientMsgValue(uint256 given, uint256 expected);
```

### SanctionedAddress

```solidity
error SanctionedAddress(address account);
```

