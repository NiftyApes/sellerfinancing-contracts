# ISellerFinancingStructs
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/c32bcc4ddea85d7a717bf9d657523b95f48a4510/src/interfaces/sellerFinancing/ISellerFinancingStructs.sol)


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

