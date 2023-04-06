# ISellerFinancingAdmin
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/sellerFinancing/ISellerFinancingAdmin.sol)


## Functions
### pause

Pauses all interactions with the contract.
This is intended to be used as an emergency measure to avoid loosing funds.


```solidity
function pause() external;
```

### unpause

Unpauses all interactions with the contract.


```solidity
function unpause() external;
```

### pauseSanctions

Pauses sanctions checks


```solidity
function pauseSanctions() external;
```

### unpauseSanctions

Unpauses sanctions checks


```solidity
function unpauseSanctions() external;
```

### updateRoyaltiesEngineContractAddress

Updates royalty engine contract address to new address


```solidity
function updateRoyaltiesEngineContractAddress(address newRoyaltyEngineContractAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRoyaltyEngineContractAddress`|`address`|New royalty engine address|


### updateDelegateRegistryContractAddress

Updates delegate registry contract address to new address


```solidity
function updateDelegateRegistryContractAddress(address newDelegateRegistryContractAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDelegateRegistryContractAddress`|`address`|New delegate registry address|


### updateSeaportContractAddress

Updates seaport contract address to new address


```solidity
function updateSeaportContractAddress(address newSeaportContractAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSeaportContractAddress`|`address`|New seaport address|


### updateWethContractAddress

Updates Weth contract address to new address


```solidity
function updateWethContractAddress(address newWethContractAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newWethContractAddress`|`address`|New Weth contract address|


