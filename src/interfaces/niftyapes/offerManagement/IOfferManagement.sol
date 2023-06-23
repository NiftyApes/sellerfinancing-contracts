//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../INiftyApesStructs.sol";

/// @title The OfferManagement interface for NiftyApes
interface IOfferManagement
{
    /// @notice Returns an EIP712 standard compatible hash for a given offer.
    /// @dev    This hash can be signed to create a valid offer.
    /// @param offer The offer to compute the hash for
    function getOfferHash(INiftyApesStructs.Offer memory offer) external view returns (bytes32);

    /// @notice Returns the signer of an offer or throws an error.
    /// @param offer The offer to use for retrieving the signer
    /// @param signature The signature to use for retrieving the signer
    function getOfferSigner(INiftyApesStructs.Offer memory offer, bytes memory signature) external returns (address);

    /// @notice Returns true if a given signature has been revoked otherwise false
    /// @param signature The signature to check
    function getOfferSignatureStatus(bytes calldata signature) external view returns (bool status);

    /// @notice Returns the usage count of a given signature
    ///         Only increments for collection offers
    /// @param signature The signature to return a count for
    function getCollectionOfferCount(bytes memory signature) external view returns (uint64 count);

    /// @notice Withdraw a given offer
    /// @dev    Calling this method allows users to withdraw a given offer by cancelling their signature on chain
    /// @param offer The offer to withdraw
    /// @param signature The signature of the offer
    function withdrawOfferSignature(INiftyApesStructs.Offer memory offer, bytes calldata signature) external;

    /// @notice Withdraws and invalidate all offers created by the caller
    /// @dev    Calling this method allows users to withdraw all their signed offers in one call
    function withdrawAllOffers() external;
}
