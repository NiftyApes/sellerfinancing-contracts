// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @title IPurchaseExecuter
/// @author zishansami102 (zishansami.eth)
/// @notice Defines the basic interface of a market integration contract to seller financing purchaser
/// @dev Implement this interface to integrate any nft marketplace to seller financing liquidity

interface IPurchaseExecuter {
    /// @notice Executes the purchase of the specified NFT from a market using the recieved funds and approves the caller 
    /// @dev Ensure that the contract approves the return of the purchased nft to the calling contract
    ///      before the end of the transaction
    /// @param nftContractAddress The address of the nft collection
    /// @param nftId The id of the specified nft
    /// @param data generic data input to be used in purchase of the NFT
    /// @return True if the execution of the operation succeeds, false otherwise
    function executePurchase(
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external payable returns (bool);
}