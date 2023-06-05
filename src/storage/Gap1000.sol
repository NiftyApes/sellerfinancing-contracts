//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @title Gap1000 contract for creating a gap of 1000 storage slot in facets
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract Gap1000 {
    /// @dev This empty reserved space is put in place to allow for facet2
    ///      to inherit this contract and thus leaving storage slots for already existing facets
    ///      occupying initial slots
    uint256[1000] private __gap;
}
