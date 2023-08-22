//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./INiftyApesAdmin.sol";
import "./INiftyApesErrors.sol";
import "./INiftyApesEvents.sol";
import "./INiftyApesStructs.sol";
import "./offerManagement/IOfferManagement.sol";
import "./loanExecution/ILoanExecution.sol";
import "./loanManagement/ILoanManagement.sol";

/// @title The overall interface for NiftyApes
interface INiftyApes is
    INiftyApesAdmin,
    INiftyApesErrors,
    INiftyApesEvents,
    INiftyApesStructs,
    IOfferManagement,
    ILoanExecution,
    ILoanManagement
{

}
