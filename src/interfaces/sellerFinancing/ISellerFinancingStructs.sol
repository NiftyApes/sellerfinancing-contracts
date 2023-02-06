//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ISellerFinancingStructs {
    struct Offer {
        // SLOT 0
        uint128 price;
        uint128 downPaymentAmount;
        // SLOT 1 - 128 remaining
        uint128 minimumPrincipalPerPeriod;
        // SLOT 2
        // offer NFT ID
        uint256 nftId;
        // SLOT 3 - 96 remaining
        // offer NFT contract address
        address nftContractAddress;
        // Offer creator
        address creator;
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        uint32 expiration;
    }

    struct Loan {
        // SLOT 0
        // The current borrower of a loan
        uint256 buyerNftId;
        // SLOT 1
        // The current lender of a loan
        uint256 sellerNftId;
        // SLOT 2
        uint128 remainingPrincipal;
        uint128 minimumPrincipalPerPeriod;
        // SLOT 3 - 128 remaining
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        uint32 periodEndTimestamp;
        uint32 periodBeginTimestamp;
    }
}
