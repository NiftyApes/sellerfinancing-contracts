// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @title ISaleExecuter
/// @author zishansami102 (zishansami.eth)
/// @notice Defines the basic interface of a market integration contract to seller financing sale of the NFTs
/// @dev Implement this interface to integrate any nft marketplace for sale of the NFTs

interface ISaleExecuter {
    /// @notice Executes the Sale of the specified NFT from a market sends back the funds to the caller
    /// @dev Ensure that the all the funds received through sale are sent back to the caller
    /// @param nftContractAddress The address of the nft collection
    /// @param nftId The id of the specified nft
    /// @param data generic data input to be used in Sale of the NFT
    /// @return True if the execution of the operation succeeds, false otherwise
    function executeSale(
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external returns (bool);
}