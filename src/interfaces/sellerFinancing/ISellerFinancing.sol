//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ISellerFinancingAdmin.sol";
import "./ISellerFinancingEvents.sol";
import "./ISellerFinancingStructs.sol";

/// @title The SellerFinancing interface for NiftyApes
///        This interface is intended to be used for interacting with SellerFinancing on the protocol
interface ISellerFinancing is
    ISellerFinancingAdmin,
    ISellerFinancingEvents,
    ISellerFinancingStructs
{
    /// @notice Returns an EIP712 standard compatible hash for a given offer
    ///         This hash can be signed to create a valid offer.
    /// @param offer The offer to compute the hash for
    function getOfferHash(SellOffer memory offer)
        external
        view
        returns (bytes32);

    /// @notice Returns the signer of an offer or throws an error.
    /// @param offer The offer to use for retrieving the signer
    /// @param signature The signature to use for retrieving the signer
    function getOfferSigner(SellOffer memory offer, bytes memory signature)
        external
        returns (address);

    /// @notice Returns true if a given signature has been revoked otherwise false
    /// @param signature The signature to check
    function getOfferSignatureStatus(bytes calldata signature)
        external
        view
        returns (bool status);

    /// @notice Withdraw a given offer
    ///         Calling this method allows users to withdraw a given offer by cancelling their signature on chain
    /// @param offer The offer to withdraw
    /// @param signature The signature of the offer
    function withdrawOfferSignature(
        SellOffer memory offer,
        bytes calldata signature
    ) external;
}
