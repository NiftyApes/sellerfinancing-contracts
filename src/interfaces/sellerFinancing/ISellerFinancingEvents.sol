//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

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
        ISellerFinancingStructs.SellOffer offer,
        bytes signature
    );

    /// @notice Emitted when a new loan is executed
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id
    /// @param receiver The receiver integration contract
    /// @param loan The loan details
    event LoanExecuted(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        address receiver,
        ISellerFinancingStructs.Loan loan
    );

    /// @notice Emitted when a payment is made toward the loan
    /// @param nftContractAddress The nft contract address
    /// @param nftId The nft id
    /// @param amount The amount paid twoard the loamn
    /// @param loan The loan details
    event PaymentMade(
        address indexed nftContractAddress,
        uint256 indexed nftId,
        uint256 amount,
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
