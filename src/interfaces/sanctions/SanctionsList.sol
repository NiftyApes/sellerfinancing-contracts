pragma solidity 0.8.21;

interface SanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}
