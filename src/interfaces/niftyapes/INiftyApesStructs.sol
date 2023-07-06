//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface INiftyApesStructs {
    enum OfferType {
        SELLER_FINANCING,
        LENDING, 
        SALE
    }

    enum ItemType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }

    struct CollateralItem {
        ItemType itemType;
        address token;
        uint256 identifier;
        uint256 amount;
    }

    struct LoanItem {
        ItemType itemType;
        address token;
        uint256 identifier;
        // Loan amount
        uint256 principalAmount;
        // Minimum amount of total principal to be paid each period
        uint128 minimumPrincipalPerPeriod;
        // Down payment for NFT financing, ignored for LENDING offers
        uint128 downPaymentAmount;
    }

    struct MarketplaceRecipient {
        address recipient;
        uint256 amount;
    }

    
    struct Offer {
        // SLOT 0
        OfferType offerType;
        // SLOT 0, 1, 2
        CollateralItem collateralItem;
        // SLOT 3, 4, 5, 6
        LoanItem loanItem;
        // SLOT 7
        // Offer creator
        address creator;
        // Interest rate basis points to be paid against remainingPrincipal per period
        uint32 periodInterestRateBps;
        // Number of seconds per period
        uint32 periodDuration;
        // Timestamp of offer expiration
        uint32 expiration;
        // SLOT 8
        // should be set to true if collection offer
        bool isCollectionOffer;
        // collection offer usage limit, ignored if not collection offer
        uint64 collectionOfferLimit;
        // Current offer nonce value of the creator
        // Offer becomes invalid if current offerNonce is increased
        uint32 creatorOfferNonce;
        // royalties will be paid from the buyer payments if offerType is SELLER_FINANCING 
        // and this set to true. Ignored in all other cases
        bool payRoyalties;
        // SLOT 9
        MarketplaceRecipient[] marketplaceRecipients;
    }

    struct Loan {
        // SLOT 0
        // Buyer loan receipt nftId
        uint256 loanId;
        // SLOT 1, 2, 3, 4
        LoanItem loanItem;
        // SLOT 5, 6, 7
        CollateralItem collateralItem;
        // SLOT 8
        // Interest rate basis points to be paid against remainingPrincipal per period
        uint32 periodInterestRateBps;
        // Number of seconds per period
        uint32 periodDuration;
        // Timestamp of period end
        uint32 periodEndTimestamp;
        // Timestamp of period beginning
        uint32 periodBeginTimestamp;
        // Pay royalties from loan payments if set to true
        bool payRoyalties;
    }
}
