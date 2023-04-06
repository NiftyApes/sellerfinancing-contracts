# ISellerFinancingStructs
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/sellerFinancing/ISellerFinancingStructs.sol)


## Structs
### Offer

```solidity
struct Offer {
    uint128 price;
    uint128 downPaymentAmount;
    uint128 minimumPrincipalPerPeriod;
    uint256 nftId;
    address nftContractAddress;
    address creator;
    uint32 periodInterestRateBps;
    uint32 periodDuration;
    uint32 expiration;
}
```

### Loan

```solidity
struct Loan {
    uint256 buyerNftId;
    uint256 sellerNftId;
    uint128 remainingPrincipal;
    uint128 minimumPrincipalPerPeriod;
    uint32 periodInterestRateBps;
    uint32 periodDuration;
    uint32 periodEndTimestamp;
    uint32 periodBeginTimestamp;
}
```

