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
        ISellerFinancingStructs.Offer offer,
        bytes signature
    );
}
