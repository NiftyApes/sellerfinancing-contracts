// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../../../src/storage/Gap1000.sol";

contract MockFacet1 is Gap1000 {

    bytes32 constant MOCK_FACET_1 = keccak256("mock.facet.1");

    struct MockStruct {
        address someAddress;
        uint256 someValue;
    }

    uint256[1000] private fullStorage;

    function init(address _mockAddress, uint256 _mockValue) external {
        MockStruct storage ms = _getMockStruct();
        ms.someAddress = _mockAddress;
        ms.someValue = _mockValue;
    }

    function mockAddress() external view returns (address) {
        MockStruct storage ms = _getMockStruct();
        return ms.someAddress;
    }

    function mockValue() external view returns (uint256) {
        MockStruct storage ms = _getMockStruct();
        return ms.someValue;
    }

    function setValueFacet1At(uint256 index, uint256 _value) external {
        require(index < 1000, "invalid index");
        fullStorage[index] = _value;
    }

    function getValueFacet1At(uint256 index) external view returns (uint256){
        require(index < 1000, "invalid index");
        return fullStorage[index];
    }

    function _getMockStruct() internal pure returns (MockStruct storage ms) {
        bytes32 position = MOCK_FACET_1;
        assembly {
            ms.slot := position
        }
    }
}