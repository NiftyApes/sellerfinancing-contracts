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

    struct Item {
        ItemType itemType;
        address token;
        uint256 identifier;
        uint256 amount;
    }

    struct Terms {
        ItemType itemtype;

        // Down payment for NFT financing, ignored for LENDING offers
        uint128 downPaymentAmount;

        // Loan offer amount, where price will be equal to `downPaymentAmount` + `principalAmount`
        uint128 principalAmount;

        // Minimum amount of total principal to be paid each period
        uint128 minimumPrincipalPerPeriod;

        // Interest rate basis points to be paid against remainingPrincipal per period
        uint32 periodInterestRateBps;

        // Number of seconds per period
        uint32 periodDuration;

    }

    struct MarketplaceRecipient {
        address recipient;
        uint256 amount; 
    }

    
    struct Offer {
        // Offer creator
        address creator;

        OfferType offerType;

        Item item;

        Terms terms;

        MarketplaceRecipient[] marketplaceRecipients;
      
        // Timestamp of offer expiration
        uint32 expiration;

        // collection offer usage limit, ignored if not collection offer
        uint64 collectionOfferLimit;

        // Current offer nonce value of the creator
        // Offer becomes invalid if current offerNonce is increased
        uint32 creatorOfferNonce;

    }

    struct Loan {
        // Buyer loan receipt nftId
        uint256 borrowerNftId;

        // Seller loan receipt nftId
        uint256 lenderNftId;

        Item item;

        // Remaining principal on loan
        uint128 remainingPrincipal;

        // Minimum amount of total principal to be paid each period
        uint128 minimumPrincipalPerPeriod;

        // Interest rate basis points to be paid against remainingPrincipal per period
        uint32 periodInterestRateBps;

        // Number of seconds per period
        uint32 periodDuration;

        // Timestamp of period end
        uint32 periodEndTimestamp;

        // Timestamp of period beginning
        uint32 periodBeginTimestamp;

    }
}
