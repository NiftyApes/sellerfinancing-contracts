//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../sellerFinancing/ISellerFinancingStructs.sol";
import "../sellerFinancing/ISellerFinancingErrors.sol";

/// @title The Lending interface for NiftyApes
interface ILending
{
    function borrow(
        ISellerFinancingStructs.Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId
    ) external payable returns (uint256 conversionAmountReceived);

    function buyWith3rdPartyFinancing(
        ISellerFinancingStructs.Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId,
        bytes calldata data
    ) external payable;
}
