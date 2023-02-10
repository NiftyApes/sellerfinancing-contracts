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
    function getOfferHash(Offer memory offer) external view returns (bytes32);

    /// @notice Returns the signer of an offer or throws an error.
    /// @param offer The offer to use for retrieving the signer
    /// @param signature The signature to use for retrieving the signer
    function getOfferSigner(Offer memory offer, bytes memory signature)
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
        Offer memory offer,
        bytes calldata signature
    ) external;

    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature A signed offerHash
    function buyWithFinancing(Offer calldata offer, bytes memory signature)
        external
        payable;

    /// @notice Returns a loan identified by a given nft.
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    function getLoan(address nftContractAddress, uint256 nftId)
        external
        view
        returns (Loan memory);

    /// @notice Returns the total NFTs from a given collection owned by a user which has active loans in NiftyApes.
    /// @param owner The address of the owner
    /// @param nftContractAddress The address of the NFT collection
    function balanceOf(address owner, address nftContractAddress)
        external
        returns (uint256);

    /// @notice Returns an NFT token ID owned by `owner` at a given `index` of its token list.
    /// @param owner The address of the user
    /// @param nftContractAddress The address of the NFT collection
    /// @param index The index of the owner's token list
    function tokenOfOwnerByIndex(
        address owner,
        address nftContractAddress,
        uint256 index
    ) external returns (uint256);

    function initialize() external;
}
