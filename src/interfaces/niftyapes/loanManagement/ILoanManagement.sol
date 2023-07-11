//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../INiftyApesStructs.sol";
import "../INiftyApesErrors.sol";

/// @title The LoanManagement interface for NiftyApes
interface ILoanManagement
{
    /// @notice Returns a loan identified by a given `loanId`
    /// @param loanId The `loanId` of the loan or `loanId+1`
    function getLoan(uint256 loanId) external view returns (INiftyApesStructs.Loan memory);

    /// @notice Returns the underlying nft of a specified ticket id.
    /// @param ticketId The id of a specified ticket id
    function getUnderlyingNft(
        uint256 ticketId
    ) external view returns (INiftyApesStructs.CollateralItem memory);

    /// @notice Returns minimum payment required for the current period and current period interest including protocol fee
    /// @dev    This function calculates a sum of current and late payment values if applicable
    /// @param  loanId The `loanId` of the loan or `loanId+1`
    /// @return minimumPayment Minimum payment required for the current period
    /// @return periodInterest Unpaid interest amount for the current period
    function calculateMinimumPayment(
        uint256 loanId
    ) external view returns (uint256 minimumPayment, uint256 periodInterest);

    /// @notice Calculates and returns protocol fee on the given loan payment amount
    /// @dev Explain to a developer any extra details
    /// @param loanPaymentAmount Payment amout to be paid for an existing loan
    function calculateProtocolFee(uint256 loanPaymentAmount) external view returns (uint256);

    /// @notice Make a partial payment or full repayment of a loan.
    /// @dev Any address may make a payment towards the loan.
    /// @param loanId The `loanId` of the loan or `loanId+1`
    function makePayment(uint256 loanId) external payable;

    /// @notice Make payments to a list of active loans
    /// @dev Any address may make a payment towards the loans.
    /// @param loanIds The list of loanIds for the payements
    /// @param payments The list of payment values for the loan
    /// @param partialExecution If set to true, will continue to attempt transaction executions even
    ///        if the any payment request had insufficient value available for the requested payment
    function makePaymentBatch(
        uint256[] memory loanIds,
        uint256[] memory payments,
        bool partialExecution
    ) external payable;

    /// @notice Seize all assets from the defaulted loans.
    /// @dev    This function is only callable by the seller address of all the given loans
    /// @param  loanIds The list of loanIds for seize
    function seizeAsset(
        uint256[] memory loanIds
    ) external;

    /// @notice Sell the underlying nft and repay the loan using the proceeds of the sale.
    ///         Transfer remaining funds to the buyer
    /// @dev    This function is only callable by the buyer address
    /// @dev    This function only supports valid Seaport orders
    /// @param loanId The `loanId` of the loan or `loanId+1`
    /// @param minProfitAmount Minimum amount to accept for buyer's profit. Provides slippage control.
    /// @param data Order encoded as bytes
    function instantSell(
        uint256 loanId,
        uint256 minProfitAmount,
        bytes calldata data
    ) external;
}
