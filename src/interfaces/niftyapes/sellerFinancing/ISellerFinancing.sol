//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./ISellerFinancingAdmin.sol";
import "../INiftyApesStructs.sol";

/// @title The SellerFinancing interface for NiftyApes
interface ISellerFinancing is
    ISellerFinancingAdmin
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

    /// @notice Returns value stored in `royaltiesEngineContractAddress`
    function royaltiesEngineContractAddress() external returns (address);

    /// @notice Returns value stored in `delegateRegistryContractAddress`
    function delegateRegistryContractAddress() external returns (address);

    /// @notice Returns value stored in `seaportContractAddress`
    function seaportContractAddress() external returns (address);

    /// @notice Returns value stored in `wethContractAddress`
    function wethContractAddress() external returns (address);

    /// @notice Withdraw a given offer
    /// @dev    Calling this method allows users to withdraw a given offer by cancelling their signature on chain
    /// @param offer The offer to withdraw
    /// @param signature The signature of the offer
    function withdrawOfferSignature(INiftyApesStructs.Offer memory offer, bytes calldata signature) external;

    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature A signed offerHash
    function buyWithSellerFinancing(
        INiftyApesStructs.Offer calldata offer,
        bytes memory signature,
        uint256 nftId
    ) external payable;

    /// @notice Make a partial payment or full repayment of a loan.
    /// @dev Any address may make a payment towards the loan.
    /// @param loanId The id of a specified loan
    function makePayment(uint256 loanId) external payable;

    /// @notice Seize an asset from a defaulted loan.
    /// @dev    This function is only callable by the seller address
    /// @param loanId The id of a specified loan
    function seizeAsset(uint256 loanId) external;

    /// @notice Sell the underlying nft and repay the loan using the proceeds of the sale.
    ///         Transfer remaining funds to the buyer
    /// @dev    This function is only callable by the buyer address
    /// @dev    This function only supports valid Seaport orders
    /// @param loanId The id of a specified loan
    /// @param minProfitAmount Minimum amount to accept for buyer's profit. Provides slippage control.
    /// @param data Order encoded as bytes
    function instantSell(
        uint256 loanId,
        uint256 minProfitAmount,
        bytes calldata data
    ) external;

    /// @notice Returns a loan identified by a given loanId.
    /// @param loanId The id of a specified loan
    function getLoan(uint256 loanId) external view returns (INiftyApesStructs.Loan memory);

    /// @notice Returns the underlying nft of a specified loanId.
    /// @param loanId The id of a specified loan
    function getUnderlyingNft(
        uint256 loanId
    ) external view returns (INiftyApesStructs.Item memory);

    /// @notice Returns minimum payment required for the current period and current period interest
    /// @dev    This function calculates a sum of current and late payment values if applicable
    /// @param loan Loan struct details
    /// @return minimumPayment Minimum payment required for the current period
    /// @return periodInterest Unpaid interest amount for the current period
    function calculateMinimumPayment(
        INiftyApesStructs.Loan memory loan
    ) external view returns (uint256 minimumPayment, uint256 periodInterest);

    function initialize(
        address newRoyaltiesEngineAddress,
        address newDelegateRegistryAddress,
        address newSeaportContractAddress,
        address newWethContractAddress
    ) external;
}
