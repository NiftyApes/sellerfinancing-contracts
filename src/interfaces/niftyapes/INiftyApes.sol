//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./sellerFinancing/ISellerFinancing.sol";
import "./sellerFinancing/ISellerFinancingEvents.sol";
import "./sellerFinancing/ISellerFinancingStructs.sol";
import "./sellerFinancing/ISellerFinancingErrors.sol";
import "./lending/ILending.sol";


/// @title The overall interface for NiftyApes
interface INiftyApes is
    ISellerFinancing,
    ISellerFinancingEvents,
    ISellerFinancingStructs,
    ISellerFinancingErrors,
    ILending
    {}
