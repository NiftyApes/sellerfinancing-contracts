// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @title IFlashPurchaseReceiver
/// @author zishansami102 (zishansami.eth)
/// @notice Defines the basic interface of a finance receiver contract using `FlashPurchase.borrowFundsForPurchase()`
/// @dev Implement this interface to integrate FlashPurchase to any nft marketplace

interface IFlashPurchaseReceiver {
    /// @notice Executes an operation after receiving the lending amount from an existing offer on NiftyApes
    /// @dev Ensure that the contract approves the return of the purchased nft to the FlashPurchase contract
    ///      before the end of the transaction
    /// @param nftContractAddress The address of the nft collection
    /// @param nftId The id of the specified nft
    /// @param initiator The address which initiated the borrow call on FlashPurchase contract
    /// @param data generic data input to be used in purchase of the NFT
    /// @return True if the execution of the operation succeeds, false otherwise
    function executeOperation(
        address nftContractAddress,
        uint256 nftId,
        address initiator,
        bytes calldata data
    ) external payable returns (bool);
}