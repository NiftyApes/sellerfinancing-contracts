# ISellerFinancingEvents
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/sellerFinancing/ISellerFinancingEvents.sol)


## Events
### OfferSignatureUsed
Emitted when a offer signature gets has been used


```solidity
event OfferSignatureUsed(
    address indexed nftContractAddress, uint256 indexed nftId, ISellerFinancingStructs.Offer offer, bytes signature
);
```

### LoanExecuted
Emitted when a new loan is executed


```solidity
event LoanExecuted(
    address indexed nftContractAddress,
    uint256 indexed nftId,
    address receiver,
    bytes offerSignature,
    ISellerFinancingStructs.Loan loan
);
```

### PaymentMade
Emitted when a payment is made toward the loan


```solidity
event PaymentMade(
    address indexed nftContractAddress,
    uint256 indexed nftId,
    uint256 amount,
    uint256 totalRoyaltiesPaid,
    uint256 interestPaid,
    ISellerFinancingStructs.Loan loan
);
```

### LoanRepaid
Emitted when a loan is fully repaid


```solidity
event LoanRepaid(address indexed nftContractAddress, uint256 indexed nftId, ISellerFinancingStructs.Loan loan);
```

### AssetSeized
Emitted when an asset is seized


```solidity
event AssetSeized(address indexed nftContractAddress, uint256 indexed nftId, ISellerFinancingStructs.Loan loan);
```

### InstantSell
Emitted when an NFT is sold instantly on Seaport


```solidity
event InstantSell(address indexed nftContractAddress, uint256 indexed nftId, uint256 saleAmount);
```

### ListedOnSeaport
Emitted when an locked NFT is listed for sale through Seaport


```solidity
event ListedOnSeaport(
    address indexed nftContractAddress,
    uint256 indexed nftId,
    bytes32 indexed orderHash,
    ISellerFinancingStructs.Loan loan
);
```

### ListingCancelledSeaport
Emitted when a seaport NFT listing thorugh NiftyApes is cancelled by the borrower


```solidity
event ListingCancelledSeaport(
    address indexed nftContractAddress,
    uint256 indexed nftId,
    bytes32 indexed orderHash,
    ISellerFinancingStructs.Loan loan
);
```

### FlashClaim
Emitted when a flashClaim is executed on an NFT


```solidity
event FlashClaim(address nftContractAddress, uint256 nftId, address receiverAddress);
```

