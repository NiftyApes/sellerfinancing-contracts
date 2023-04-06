# IFlashClaimReceiver
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/c32bcc4ddea85d7a717bf9d657523b95f48a4510/src/flashClaim/interfaces/IFlashClaimReceiver.sol)

**Author:**
captnseagraves

Defines the basic interface of a flashClaimReceiver contract.

*Implement this interface to develop a flashClaim-compatible flashClaimReceiver contract*


## Functions
### executeOperation

Executes an operation after receiving the flash claimed nft

*Ensure that the contract approves the FlashClaim contract to transferFrom
the NFT back to the Lending contract before the end of the transaction*


```solidity
function executeOperation(address initiator, address nftContractAddress, uint256 nftId, bytes calldata data)
    external
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initiator`|`address`|The initiator of the flashClaim|
|`nftContractAddress`|`address`|The address of the nft collection|
|`nftId`|`uint256`|The id of the specified nft|
|`data`|`bytes`|Arbitrary data structure, intended to contain user-defined parameters|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the execution of the operation succeeds, false otherwise|


