//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../INiftyApesStructs.sol";

/// @title The batch execution interface for NiftyApes
interface IBatchExecution {
    /// @notice Execute loan offers in batch for buyer
    /// @param offers The list of the offers to execute
    /// @param signatures The list of corresponding signatures from the offer creators
    /// @param buyer The address of the buyer
    /// @param tokenIds The tokenIds of the tokens the buyer intends to buy
    /// @param tokenAmounts The amount of the tokens the buyer intends to buy
    /// @param partialExecution If set to true, will continue to attempt offer executions regardless
    ///        if previous offers have failed or had insufficient value available
    function buyWithSellerFinancingBatch(
        INiftyApesStructs.Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external payable returns (uint256[] memory loanIds);

    /// @notice Execute loan offers in batch for borrower
    /// @param offers The list of the offers to execute
    /// @param signatures The list of corresponding signatures from the offer creators
    /// @param borrower The address of the buyer
    /// @param tokenIds The tokenIds of the tokens the buyer intends to buy
    /// @param tokenAmounts The amount of the tokens the buyer intends to buy
    /// @param partialExecution If set to true, will continue to attempt offer executions regardless
    ///        if previous offers have failed or had insufficient value available
    function borrowBatch(
        INiftyApesStructs.Offer[] calldata offers,
        bytes[] calldata signatures,
        address borrower,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external returns (uint256[] memory loanIds);

    /// @notice Executes buyWith3rdPartyFinancing in batch
    /// @param offers The list of the offers to execute
    /// @param signatures The list of corresponding signatures from the offer creators
    /// @param borrower The address of the buyer
    /// @param tokenIds The tokenIds of the tokens the buyer intends to buy
    /// @param tokenAmounts The amount of the tokens the buyer intends to buy
    /// @param data         The list of Seaport Lsiting Order data encoded as bytes
    /// @param partialExecution If set to true, will continue to attempt offer executions regardless
    ///        if previous offers have failed or had insufficient value available
    function buyWith3rdPartyFinancingBatch(
        INiftyApesStructs.Offer[] calldata offers,
        bytes[] calldata signatures,
        address borrower,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bytes[] calldata data,
        bool partialExecution
    ) external returns (uint256[] memory loanIds);

    /// @notice Executes buyNow in batch for buyer
    /// @param offers The list of the offers to execute
    /// @param signatures The list of corresponding signatures from the offer creators
    /// @param buyer The address of the buyer
    /// @param tokenIds The tokenIds of the tokens the buyer intends to buy
    /// @param tokenAmounts The amount of the tokens the buyer intends to buy
    /// @param partialExecution If set to true, will continue to attempt offer executions regardless
    ///        if previous offers have failed or had insufficient value available
    function buyNowBatch(
        INiftyApesStructs.Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external payable;

    /// @notice Execute instantSell on all the NFTs in the provided input
    /// @param loanIds The list of all the token IDs
    /// @param minProfitAmounts List of minProfitAmount for each `instantSell` call
    /// @param data The list of data to be passed to each `instantSell` call
    /// @param partialExecution If set to true, will continue to attempt next request in the loop
    ///        when one `instantSell` or transfer ticket call fails
    function instantSellBatch(
        uint256[] memory loanIds,
        uint256[] memory minProfitAmounts,
        bytes[] calldata data,
        bool partialExecution
    ) external;
}
