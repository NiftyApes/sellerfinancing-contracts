//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./ISellerFinancingStructs.sol";

/// @title Events emitted by the offers part of the protocol.
interface ISellerFinancingEvents {
    /// @notice Emitted when a offer signature gets has been used
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id, this field can be meaningless if the offer is a floor term offer
    /// @param offer The offer details
    /// @param signature The signature that has been revoked
    event OfferSignatureUsed(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        ISellerFinancingStructs.Offer offer,
        bytes signature
    );

    /// @notice Emitted when a new loan is executed
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id
    /// @param signature The signature that has been used
    /// @param loan The loan details
    event LoanExecuted(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        bytes signature,
        ISellerFinancingStructs.Loan loan
    );

    /// @notice Emitted when a payment is made toward the loan
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id
    /// @param amount The amount paid towards the loan
    /// @param totalRoyaltiesPaid The amount paid in royalties
    /// @param interestPaid the amount paid in interest
    /// @param loan The loan details
    event PaymentMade(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        uint256 amount,
        uint256 totalRoyaltiesPaid,
        uint256 interestPaid,
        ISellerFinancingStructs.Loan loan
    );

    /// @notice Emitted when a loan is fully repaid
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id
    /// @param loan The loan details
    event LoanRepaid(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        ISellerFinancingStructs.Loan loan
    );

    /// @notice Emitted when an asset is seized
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id
    /// @param loan The loan details
    event AssetSeized(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        ISellerFinancingStructs.Loan loan
    );
}
