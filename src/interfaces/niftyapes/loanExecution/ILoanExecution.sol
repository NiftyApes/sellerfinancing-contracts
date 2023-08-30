//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../INiftyApesStructs.sol";

/// @title The LoanManagement interface for NiftyApes
interface ILoanExecution {
    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature A signed offerHash
    /// @param buyer The address of the buyer
    /// @param tokenId The id of a specified token
    /// @param tokenAmount Amount of the specified token if ERC1155
    /// @dev   buyer provided as param to allow for 3rd party marketplace integrations
    function buyWithSellerFinancing(
        INiftyApesStructs.Offer calldata offer,
        bytes memory signature,
        address buyer,
        uint256 tokenId,
        uint256 tokenAmount
    ) external payable returns (uint256 loanId);

    /// @notice Start a loan as a borrower using a signed Lending Offer from a lender.
    /// @param offer        The details of the lending offer
    /// @param signature    A signed offerHash
    /// @param borrower     The address of the borrower
    /// @param tokenId      The id of a specified token
    /// @param tokenAmount  Amount of the specified token if ERC1155
    /// @dev   borrower provided as param to allow for 3rd party marketplace integrations
    function borrow(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 tokenId,
        uint256 tokenAmount
    ) external returns (uint256 loanId);

    /// @notice Executes the NFT purchase and starts a loan using the fund from lender who signed the Lending Offer
    /// @param offer        The details of the lending offer
    /// @param signature    A signed offerHash
    /// @param borrower     The address of the borrower
    /// @param tokenId        The id of a specified token
    /// @param tokenAmount Amount of the specified token if ERC1155
    /// @param data         Seaport Lsiting Order data encoded as bytes
    /// @dev   borrower provided as param to allow for 3rd party marketplace integrations
    function buyWith3rdPartyFinancing(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 tokenId,
        uint256 tokenAmount,
        bytes calldata data
    ) external returns (uint256 loanId);

    /// @notice Executes a purchase of collateral item from the signed offer without any loan.
    /// @param offer The details of the offer
    /// @param signature A signed offerHash
    /// @param buyer The address of the buyer
    /// @param tokenId The id of a specified token
    /// @param tokenAmount Amount of the specified token if ERC1155
    /// @dev   buyer provided as param to allow for 3rd party marketplace integrations
    function buyNow(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 tokenId,
        uint256 tokenAmount
    ) external payable;
}
