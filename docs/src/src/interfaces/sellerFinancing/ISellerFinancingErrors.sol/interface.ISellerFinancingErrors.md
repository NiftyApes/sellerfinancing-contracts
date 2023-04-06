# ISellerFinancingErrors
[Git Source](https://github.com/NiftyApes/sellerFinancing/blob/f6ca9d9e78c8f1005882d5e3953bf8db14722758/src/interfaces/sellerFinancing/ISellerFinancingErrors.sol)


## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### SignatureNotAvailable

```solidity
error SignatureNotAvailable(bytes signature);
```

### NotSignature65

```solidity
error NotSignature65(bytes signature);
```

### OfferExpired

```solidity
error OfferExpired();
```

### SanctionedAddress

```solidity
error SanctionedAddress(address account);
```

### NotNftOwner

```solidity
error NotNftOwner(address nftContractAddress, uint256 nftId, address account);
```

### InvalidSigner

```solidity
error InvalidSigner(address signer, address expected);
```

### LoanAlreadyOpen

```solidity
error LoanAlreadyOpen();
```

### LoanAlreadyClosed

```solidity
error LoanAlreadyClosed();
```

### MsgSenderNotSeller

```solidity
error MsgSenderNotSeller();
```

### MsgSenderNotBuyer

```solidity
error MsgSenderNotBuyer();
```

### CannotBuySellerFinancingTicket

```solidity
error CannotBuySellerFinancingTicket();
```

### InvalidOffer0ItemType

```solidity
error InvalidOffer0ItemType(ISeaport.ItemType given, ISeaport.ItemType expected);
```

### InvalidOffer0Token

```solidity
error InvalidOffer0Token(address given, address expected);
```

### InvalidConsideration0Identifier

```solidity
error InvalidConsideration0Identifier(uint256 given, uint256 expected);
```

### InvalidConsiderationItemType

```solidity
error InvalidConsiderationItemType(uint256 index, ISeaport.ItemType given, ISeaport.ItemType expected);
```

### InvalidConsiderationToken

```solidity
error InvalidConsiderationToken(uint256 index, address given, address expected);
```

### InvalidPeriodDuration

```solidity
error InvalidPeriodDuration();
```

### InsufficientMsgValue

```solidity
error InsufficientMsgValue(uint256 msgValueSent, uint256 minMsgValueExpected);
```

### DownPaymentGreaterThanOrEqualToOfferPrice

```solidity
error DownPaymentGreaterThanOrEqualToOfferPrice(uint256 downPaymentAmount, uint256 offerPrice);
```

### InvalidMinimumPrincipalPerPeriod

```solidity
error InvalidMinimumPrincipalPerPeriod(uint256 givenMinPrincipalPerPeriod, uint256 maxMinPrincipalPerPeriod);
```

### SoftGracePeriodEnded

```solidity
error SoftGracePeriodEnded();
```

### AmountReceivedLessThanRequiredMinimumPayment

```solidity
error AmountReceivedLessThanRequiredMinimumPayment(uint256 amountReceived, uint256 minExpectedAmount);
```

### LoanNotInDefault

```solidity
error LoanNotInDefault();
```

### ExecuteOperationFailed

```solidity
error ExecuteOperationFailed();
```

### SeaportOrderNotFulfilled

```solidity
error SeaportOrderNotFulfilled();
```

### WethConversionFailed

```solidity
error WethConversionFailed();
```

### InsufficientAmountReceivedFromSale

```solidity
error InsufficientAmountReceivedFromSale(uint256 saleAmountReceived, uint256 minSaleAmountRequired);
```

### InvalidIndex

```solidity
error InvalidIndex(uint256 index, uint256 ownerTokenBalance);
```

### InsufficientBalance

```solidity
error InsufficientBalance(uint256 amountRequested, uint256 contractBalance);
```

### ConditionSendValueFailed

```solidity
error ConditionSendValueFailed(address from, address to, uint256 amount);
```

