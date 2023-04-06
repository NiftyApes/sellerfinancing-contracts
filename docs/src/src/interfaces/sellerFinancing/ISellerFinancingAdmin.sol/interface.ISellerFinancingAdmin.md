# ISellerFinancingAdmin
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/c32bcc4ddea85d7a717bf9d657523b95f48a4510/src/interfaces/sellerFinancing/ISellerFinancingAdmin.sol)


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


