//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @title Gap2000 contract for creating a gap of 2000 storage slot in facet3
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract Gap2000 {
    /// @dev This empty reserved space is put in place to allow facet3
    ///      to inherit this contract and thus leaving storage slots for already existing facets
    ///      occupying initial slots
    uint256[2000] private __gap;
}
