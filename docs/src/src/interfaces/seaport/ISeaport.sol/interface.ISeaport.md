# ISeaport
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/seaport/ISeaport.sol)


## Functions
### getCounter

Retrieve the current counter for a given offerer.


```solidity
function getCounter(address offerer) external view returns (uint256 counter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offerer`|`address`|The offerer in question.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`counter`|`uint256`|The current counter.|


### getOrderStatus

Retrieve the status of a given order by hash, including whether
the order has been cancelled or validated and the fraction of the
order that has been filled.


```solidity
function getOrderStatus(bytes32 orderHash)
    external
    view
    returns (bool isValidated, bool isCancelled, uint256 totalFilled, uint256 totalSize);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`orderHash`|`bytes32`|The order hash in question.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isValidated`|`bool`|A boolean indicating whether the order in question has been validated (i.e. previously approved or partially filled).|
|`isCancelled`|`bool`|A boolean indicating whether the order in question has been cancelled.|
|`totalFilled`|`uint256`|The total portion of the order that has been filled (i.e. the "numerator").|
|`totalSize`|`uint256`|  The total size of the order that is either filled or unfilled (i.e. the "denominator").|


### getOrderHash

Retrieve the order hash for a given order.


```solidity
function getOrderHash(OrderComponents calldata order) external view returns (bytes32 orderHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`order`|`OrderComponents`|The components of the order.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`orderHash`|`bytes32`|The order hash.|


### fulfillOrder


```solidity
function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey) external payable returns (bool fulfilled);
```

### validate


```solidity
function validate(Order[] memory orders) external returns (bool validated);
```

### cancel


```solidity
function cancel(OrderComponents[] memory orders) external returns (bool cancelled);
```

## Structs
### OfferItem
*An offer item has five components: an item type (ETH or other native
tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
ERC1155), a token address, a dual-purpose "identifierOrCriteria"
component that will either represent a tokenId or a merkle root
depending on the item type, and a start and end amount that support
increasing or decreasing amounts over the duration of the respective
order.*


```solidity
struct OfferItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
}
```

### ConsiderationItem
*A consideration item has the same five components as an offer item and
an additional sixth component designating the required recipient of the
item.*


```solidity
struct ConsiderationItem {
    ItemType itemType;
    address token;
    uint256 identifierOrCriteria;
    uint256 startAmount;
    uint256 endAmount;
    address payable recipient;
}
```

### OrderComponents
*An order contains eleven components: an offerer, a zone (or account that
can cancel the order or restrict who can fulfill the order depending on
the type), the order type (specifying partial fill support as well as
restricted order status), the start and end time, a hash that will be
provided to the zone when validating restricted orders, a salt, a key
corresponding to a given conduit, a counter, and an arbitrary number of
offer items that can be spent along with consideration items that must
be received by their respective recipient.*


```solidity
struct OrderComponents {
    address offerer;
    address zone;
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 counter;
}
```

### OrderParameters
*The full set of order components, with the exception of the counter,
must be supplied when fulfilling more sophisticated orders or groups of
orders. The total number of original consideration items must also be
supplied, as the caller may specify additional consideration items.*


```solidity
struct OrderParameters {
    address offerer;
    address zone;
    OfferItem[] offer;
    ConsiderationItem[] consideration;
    OrderType orderType;
    uint256 startTime;
    uint256 endTime;
    bytes32 zoneHash;
    uint256 salt;
    bytes32 conduitKey;
    uint256 totalOriginalConsiderationItems;
}
```

### Order
*Orders require a signature in addition to the other order parameters.*


```solidity
struct Order {
    OrderParameters parameters;
    bytes signature;
}
```

## Enums
### OrderType

```solidity
enum OrderType {
    FULL_OPEN,
    PARTIAL_OPEN,
    FULL_RESTRICTED,
    PARTIAL_RESTRICTED
}
```

### ItemType

```solidity
enum ItemType {
    NATIVE,
    ERC20,
    ERC721,
    ERC1155,
    ERC721_WITH_CRITERIA,
    ERC1155_WITH_CRITERIA
}
```

