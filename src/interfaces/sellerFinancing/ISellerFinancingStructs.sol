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

    struct SeaportListing {
        address nftContractAddress;
        uint256 nftId;
        uint256 listingValue;
    }

    struct LoanAuction {
        // SLOT 0 START
        // The original owner of the nft.
        // If there is an active loan on an nft, nifty apes contracts become the holder (original owner)
        // of the underlying nft. This field tracks who to return the nft to if the loan gets repaid.
        address nftOwner;
        // end timestamp of loan
        uint32 loanEndTimestamp;
        // The current lender of a loan
        address lender;
        // SLOT 1 START
        // the asset in which the loan has been denominated
        address asset;
        // beginning timestamp of loan
        uint32 loanBeginTimestamp;
        // The maximum amount of tokens that can be drawn from this loan
        uint128 amount;
        // SLOT 3 START
        // This fee is the rate of interest per second for the protocol
        uint96 protocolInterestRatePerSecond;
        // 32 unused bytes in slot 3
    }
}
