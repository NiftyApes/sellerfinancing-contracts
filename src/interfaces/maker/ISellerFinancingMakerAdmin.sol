//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @title NiftyApes interface for the admin role.
interface ISellerFinancingMakerAdmin {
    /// @notice Withdraws given amount from the contract balance
    /// @param  _amount The amount in wei to withdraw
    function withdraw(uint256 _amount) external;

    function updateSellerFinancingContractAddress(
        address newSellerFinancingContractAddress
    ) external;

    function setApprovalForSigner(
        address account, bool isApproved
    ) external;

    /// @notice Pauses all interactions with the contract.
    ///         This is intended to be used as an emergency measure to avoid loosing funds.
    function pause() external;

    /// @notice Unpauses all interactions with the contract.
    function unpause() external;

    function initialize(
        address newSellerFinancingContractAddress
    ) external;
}