// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import { IFlashClaimReceiver } from "../interfaces/IFlashClaimReceiver.sol";

/// @title FlashClaimReceiverBase
/// @author captnseagaves
/// @notice Base contract to develop a FlashCaimReceiver contract.
abstract contract FlashClaimReceiverBase is IFlashClaimReceiver, ERC721HolderUpgradeable {
    // do logic here
}
