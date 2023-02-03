//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ISellerFinancingStructs {
    struct Offer {
        // Offer creator
        address creator;
        uint128 price;
        uint128 downPaymentAmount;
        uint32 minimumPrincipalPerPeriod;
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        // offer NFT contract address
        address nftContractAddress;
        // offer NFT ID
        uint256 nftId;
        uint32 expiration;
    }

    struct Loan {
        // The current borrower of a loan
        uint256 buyerNftId;
        // The current lender of a loan
        uint256 sellerNftId;
        uint128 remainingPrincipal;
        uint32 minimumPrincipalPerPeriod;
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        uint32 periodEndTimestamp;
        uint32 periodBeginTimestamp;
    }
}
