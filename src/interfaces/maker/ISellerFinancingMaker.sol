//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ISellerFinancingMakerAdmin.sol";
import "../sellerFinancing/ISellerFinancing.sol";


/// @title The SellerFinancing interface for NiftyApes
///        This interface is intended to be used for interacting with SellerFinancing on the protocol
interface ISellerFinancingMaker is
    ISellerFinancingMakerAdmin
{
    /// @notice Returns the address of the EOA allowed to sign the offers
    function getAllowedSigner() external returns (address);

    /// @notice Returns the address of the cuurently set SellerFinancing Contract
    function getSellerFinancingContractAddress() external returns (address);

    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature A signed offerHash
    /// @param buyer The address of the buyer
    /// @param purchaseExecuter The contract address which executes the purchase
    /// @param data Data in bytes to be passed to purchase executer
    function buyWithFinancing(
        ISellerFinancing.Offer calldata offer,
        bytes memory signature,
        address buyer,
        address purchaseExecuter,
        bytes calldata data
    ) external payable;
}
