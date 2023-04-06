# IRoyaltyEngineV1
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/royaltyRegistry/IRoyaltyEngineV1.sol)

**Inherits:**
IERC165Upgradeable

*Lookup engine interface*


## Functions
### getRoyalty

Get the royalty for a given token (address, id) and value amount.  Does not cache the bps/amounts.  Caches the spec for a given token address


```solidity
function getRoyalty(address tokenAddress, uint256 tokenId, uint256 value)
    external
    returns (address payable[] memory recipients, uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddress`|`address`|- The address of the token|
|`tokenId`|`uint256`|     - The id of the token|
|`value`|`uint256`|       - The value you wish to get the royalty of returns Two arrays of equal length, royalty recipients and the corresponding amount each recipient should get|


### getRoyaltyView

View only version of getRoyalty


```solidity
function getRoyaltyView(address tokenAddress, uint256 tokenId, uint256 value)
    external
    view
    returns (address payable[] memory recipients, uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenAddress`|`address`|- The address of the token|
|`tokenId`|`uint256`|     - The id of the token|
|`value`|`uint256`|       - The value you wish to get the royalty of returns Two arrays of equal length, royalty recipients and the corresponding amount each recipient should get|


