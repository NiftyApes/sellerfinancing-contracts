//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../INiftyApesStructs.sol";
import "../INiftyApesErrors.sol";

/// @title The Lending interface for NiftyApes
interface ILending
{
    /// @notice Start a loan as a borrower using a signed Lending Offer from a lender.
    /// @param offer        The details of the lending offer
    /// @param signature    A signed offerHash
    /// @param borrower     The address of the borrower
    /// @param nftId        The id of a specified NFT
    /// @dev   borrower provided as param to allow for 3rd party marketplace integrations
    function borrow(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId
    ) external returns (uint256 conversionAmountReceived);

    /// @notice Executes the NFT purchase and starts a loan using the fund from lender who signed the Lending Offer
    /// @param offer        The details of the lending offer
    /// @param signature    A signed offerHash
    /// @param borrower     The address of the borrower
    /// @param nftId        The id of a specified NFT
    /// @param data         Seaport Lsiting Order data encoded as bytes
    /// @dev   borrower provided as param to allow for 3rd party marketplace integrations
    function buyWith3rdPartyFinancing(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId,
        bytes calldata data
    ) external;
}
