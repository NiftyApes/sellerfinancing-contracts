// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../../../src/storage/Gap2000.sol";

contract MockFacet2 is Gap2000 {

    uint256[1000] private fullStorage;

    function setValueFacet2At(uint256 index, uint256 _value) external {
        require(index < 1000, "invalid index");
        fullStorage[index] = _value;
    }

    function getValueFacet2At(uint256 index) external view returns (uint256){
        require(index < 1000, "invalid index");
        return fullStorage[index];
    }
}