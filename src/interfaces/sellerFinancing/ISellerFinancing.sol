//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ISellerFinancingAdmin.sol";
import "./ISellerFinancingEvents.sol";
import "./ISellerFinancingStructs.sol";
import "./ISellerFinancingErrors.sol";

/// @title The SellerFinancing interface for NiftyApes
interface ISellerFinancing is
    ISellerFinancingAdmin,
    ISellerFinancingEvents,
    ISellerFinancingStructs,
    ISellerFinancingErrors
{
    /// @notice Returns an EIP712 standard compatible hash for a given offer.
    /// @dev    This hash can be signed to create a valid offer.
    /// @param offer The offer to compute the hash for
    function getOfferHash(Offer memory offer) external view returns (bytes32);

    /// @notice Returns the signer of an offer or throws an error.
    /// @param offer The offer to use for retrieving the signer
    /// @param signature The signature to use for retrieving the signer
    function getOfferSigner(Offer memory offer, bytes memory signature) external returns (address);

    /// @notice Returns true if a given signature has been revoked otherwise false
    /// @param signature The signature to check
    function getOfferSignatureStatus(bytes calldata signature) external view returns (bool status);

    /// @notice Withdraw a given offer
    /// @dev    Calling this method allows users to withdraw a given offer by cancelling their signature on chain
    /// @param offer The offer to withdraw
    /// @param signature The signature of the offer
    function withdrawOfferSignature(Offer memory offer, bytes calldata signature) external;

    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature A signed offerHash
    /// @param buyer The address of the buyer
    /// @dev   buyer provided as param to allow for 3rd party marketplace integrations
    function buyWithFinancing(
        Offer calldata offer,
        bytes memory signature,
        address buyer
    ) external payable;

    /// @notice Make a partial payment or full repayment of a loan.
    /// @dev Any address may make a payment towards the loan.
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    function makePayment(address nftContractAddress, uint256 nftId) external payable;

    /// @notice Seize an asset from a defaulted loan.
    /// @dev    This function is only callable by the seller address
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    function seizeAsset(address nftContractAddress, uint256 nftId) external;

    /// @notice Sell the underlying nft and repay the loan using the proceeds of the sale.
    ///         Transfer remaining funds to the buyer
    /// @dev    This function is only callable by the buyer address
    /// @dev    This function only supports valid Seaport orders
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    /// @param minProfitAmount Minimum amount to accept for buyer's profit. Provides slippage control.
    /// @param data Order encoded as bytes
    function instantSell(
        address nftContractAddress,
        uint256 nftId,
        uint256 minProfitAmount,
        bytes calldata data
    ) external;

    /// @notice Allows an nftOwner to claim their nft and perform arbtrary actions (claim airdrops, vote in goverance, etc)
    ///         while maintaining their loan
    /// @param receiver The address of the external contract that will receive and return the nft
    /// @param nftContractAddress The address of the nft collection
    /// @param nftId The id of the specified nft
    /// @param data Arbitrary data structure, intended to contain user-defined parameters
    function flashClaim(
        address receiver,
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external;

    /// @notice Returns a loan identified by a given nft.
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    function getLoan(address nftContractAddress, uint256 nftId) external view returns (Loan memory);

    /// @notice Returns the total NFTs from a given collection owned by a user which has active loans in NiftyApes.
    /// @param owner The address of the owner
    /// @param nftContractAddress The address of the NFT collection
    function balanceOf(address owner, address nftContractAddress) external returns (uint256);

    /// @notice Returns an NFT token ID owned by `owner` at a given `index` of its token list.
    /// @param owner The address of the user
    /// @param nftContractAddress The address of the NFT collection
    /// @param index The index of the owner's token list
    function tokenOfOwnerByIndex(
        address owner,
        address nftContractAddress,
        uint256 index
    ) external returns (uint256);

    /// @notice Returns minimum payment required for the current period and current period interest
    /// @dev    This function calculates a sum of current and late payment values if applicable
    /// @param loan Loan struct details
    /// @return minimumPayment Minimum payment required for the current period
    /// @return periodInterest Unpaid interest amount for the current period
    function calculateMinimumPayment(
        Loan memory loan
    ) external view returns (uint256 minimumPayment, uint256 periodInterest);

    function initialize(
        address newRoyaltiesEngineAddress,
        address newSeaportContractAddress,
        address newWethContractAddress
    ) external;
}
