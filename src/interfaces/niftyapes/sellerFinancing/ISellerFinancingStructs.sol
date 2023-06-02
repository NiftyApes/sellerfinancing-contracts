//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISellerFinancingStructs {
    enum OfferType {
        SELLER_FINANCING,
        LENDING
    }
    
    struct Offer {
        // SLOT 0
        OfferType offerType;
        // Down payment for NFT financing
        uint128 downPaymentAmount;
        // SLOT 1
        // Loan offer amount, where price will be equal to `downPaymentAmount` + `principalAmount`
        uint128 principalAmount;
        // Minimum amount of total principal to be paid each period
        uint128 minimumPrincipalPerPeriod;
        // SLOT 2
        // Offer NFT IDs
        uint256 nftId;
        // SLOT 3
        // Offer NFT contract address
        address nftContractAddress;
        // Interest rate basis points to be paid against remainingPrincipal per period
        uint32 periodInterestRateBps;
        // Number of seconds per period
        uint32 periodDuration;
        // Timestamp of offer expiration
        uint32 expiration;
        // SLOT 4 - 32 remaining
        // Offer creator
        address creator;
        // should be set to true if collection offer
        bool isCollectionOffer;
        // collection offer usage limit, ignored if not collection offer
        uint64 collectionOfferLimit;
    }

    struct Loan {
        // SLOT 0
        // Buyer loan receipt nftId
        uint256 buyerNftId;
        // SLOT 1
        // Seller loan receipt nftId
        uint256 sellerNftId;
        // SLOT 2
        // Remaining principal on loan
        uint128 remainingPrincipal;
        // Minimum amount of total principal to be paid each period
        uint128 minimumPrincipalPerPeriod;
        // SLOT 3 - 128 remaining
        // Interest rate basis points to be paid against remainingPrincipal per period
        uint32 periodInterestRateBps;
        // Number of seconds per period
        uint32 periodDuration;
        // Timestamp of period end
        uint32 periodEndTimestamp;
        // Timestamp of period beginning
        uint32 periodBeginTimestamp;
    }

    struct UnderlyingNft {
        // NFT contract address
        address nftContractAddress;
        // NFT ID
        uint256 nftId;
    }
}
