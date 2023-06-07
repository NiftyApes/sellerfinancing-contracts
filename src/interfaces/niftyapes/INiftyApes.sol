//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./sellerFinancing/ISellerFinancing.sol";
import "./sellerFinancing/ISellerFinancingEvents.sol";
import "./INiftyApesStructs.sol";
import "./INiftyApesErrors.sol";
import "./lending/ILending.sol";


/// @title The overall interface for NiftyApes
interface INiftyApes is
    ISellerFinancing,
    ISellerFinancingEvents,
    INiftyApesStructs,
    INiftyApesErrors,
    ILending
    {}
