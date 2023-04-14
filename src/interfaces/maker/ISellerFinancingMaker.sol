//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ISellerFinancingMakerAdmin.sol";
import "../sellerFinancing/ISellerFinancing.sol";


/// @title The SellerFinancing interface for NiftyApes
///        This interface is intended to be used for interacting with SellerFinancing on the protocol
interface ISellerFinancingMaker is
    ISellerFinancingMakerAdmin
{
    /// @notice Returns true if the account is approved to sign the offers on behalf of maker,
    ///         false otherwise
    function isApprovedSigner(address account) external returns (bool);

    /// @notice Returns the address of the cuurently set SellerFinancing Contract
    function getSellerFinancingContractAddress() external returns (address);

    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature A signed offerHash
    /// @param buyer The address of the buyer
    /// @param nftId The tokenId of the nft
    /// @param purchaseExecuter The contract address which executes the purchase
    /// @param data Data in bytes to be passed to purchase executer
    function buyWithFinancing(
        ISellerFinancing.Offer calldata offer,
        bytes memory signature,
        address buyer,
        uint256 nftId,
        address purchaseExecuter,
        bytes calldata data
    ) external payable;

    function seizeAndSellNft(
        address nftContractAddress,
        uint256 nftId,
        address saleExecuter,
        uint256 minSaleAmount, // for slippage control
        bytes calldata data
    ) external returns (uint256 saleAmountReceived);
}