//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../INiftyApesStructs.sol";
import "../INiftyApesErrors.sol";

/// @title The LoanManagement interface for NiftyApes
interface ILoanManagement
{
    /// @notice Returns a loan identified by a given nft.
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    function getLoan(address nftContractAddress, uint256 nftId) external view returns (INiftyApesStructs.Loan memory);

    /// @notice Returns the underlying nft of a specified a seller financing ticket id.
    /// @param sellerFinancingTicketId The id of a specified seller financing ticket id
    function getUnderlyingNft(
        uint256 sellerFinancingTicketId
    ) external view returns (INiftyApesStructs.UnderlyingNft memory);

    /// @notice Returns minimum payment required for the current period and current period interest including protocol fee
    /// @dev    This function calculates a sum of current and late payment values if applicable
    /// @param loan Loan struct details
    /// @return minimumPayment Minimum payment required for the current period
    /// @return periodInterest Unpaid interest amount for the current period
    function calculateMinimumPayment(
        INiftyApesStructs.Loan memory loan
    ) external view returns (uint256 minimumPayment, uint256 periodInterest);

    /// @notice Calculates and returns protocol fee on the given loan payment amount
    /// @dev Explain to a developer any extra details
    /// @param loanPaymentAmount Payment amout to be paid for an existing loan
    function calculateProtocolFee(uint256 loanPaymentAmount) external view returns (uint256);

    /// @notice Make a partial payment or full repayment of a loan.
    /// @dev Any address may make a payment towards the loan.
    /// @param nftContractAddress The address of the NFT collection
    /// @param nftId The id of a specified NFT
    function makePayment(address nftContractAddress, uint256 nftId) external payable;

    /// @notice Make payments to a list of active loans
    /// @dev Any address may make a payment towards the loans.
    /// @param nftContractAddresses The list of addresses of the NFT collections
    /// @param nftIds The list of ids of the specified NFTs
    /// @param payments The list of payment values for the loan
    /// @param partialExecution If set to true, will continue to attempt transaction executions even
    ///        if the any payment request had insufficient value available for the requested payment
    function makePaymentBatch(
        address[] memory  nftContractAddresses,
        uint256[] memory nftIds,
        uint256[] memory payments,
        bool partialExecution
    ) external payable;

    /// @notice Seize all assets from the defaulted loans.
    /// @dev    This function is only callable by the seller address of all the given loans
    /// @param  nftContractAddresses The list of addresses of the NFT collections
    /// @param  nftIds The list of ids of the specified NFTs
    function seizeAsset(
        address[] memory nftContractAddresses,
        uint256[] memory nftIds
    ) external;

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
}
