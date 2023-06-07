// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../../../src/facets/common/NiftyApesInternal.sol";

contract MockFacet1 is NiftyApesInternal {

    bytes32 constant MOCK_FACET_1 = keccak256("mock.facet.1");

    struct MockStruct {
        address someAddress;
        uint256 someValue;
    }

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

    function _getMockStruct() internal pure returns (MockStruct storage ms) {
        bytes32 position = MOCK_FACET_1;
        assembly {
            ms.slot := position
        }
    }
}