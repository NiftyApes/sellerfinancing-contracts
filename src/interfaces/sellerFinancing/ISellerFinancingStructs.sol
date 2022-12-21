//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ISellerFinancingStructs {
    struct Offer {
        // SLOT 0 START
        // Offer creator
        address creator;
        uint32 downPaymentBps;
        uint32 payPeriodPrincipalBps;
        uint32 payPeriodInterestRateBps;
        uint32 payPeriodDuration;
        uint32 gracePeriodDuration;
        uint32 numLatePaymentTolerance;
        // offer NFT contract address
        address nftContractAddress;
        // SLOT 2 START
        // offer NFT ID
        uint256 nftId; // ignored if floorTerm is true
        // SLOT 3 START
        // offer asset type
        address asset;
        uint32 expiration;
    }

    struct Loan {
        // SLOT 0 START
        // The original owner of the nft.
        // If there is an active loan on an nft, nifty apes contracts become the holder (original owner)
        // of the underlying nft. This field tracks who to return the nft to if the loan gets repaid.
        address buyer;
        // end timestamp of loan
        uint32 loanEndTimestamp;
        // The current lender of a loan
        address seller;
        // SLOT 1 START
        // the asset in which the loan has been denominated
        address asset;
        // beginning timestamp of loan
        uint32 loanBeginTimestamp;
        // beginning timestamp of loan
        uint32 lastUpdatedTimestamp;
        // The maximum amount of tokens that can be drawn from this loan
        // change amount to principal
        uint128 amount;
        // SLOT 3 START
        uint32 downPaymentBps;
        uint32 payPeriodPrincipalBps;
        uint32 payPeriodInterestRateBps;
        // when someone makes a payment, does the next payment period begin after that payment or on a regular schedule?
        uint32 payPeriodDuration;
        uint32 gracePeriodDuration;
        uint32 numLatePaymentTolerance;
        uint32 numLatePayments;
        // should we have a numPayPeriods value?
    }

    struct SeaportListing {
        address nftContractAddress;
        uint256 nftId;
        uint256 listingValue;
    }
}
