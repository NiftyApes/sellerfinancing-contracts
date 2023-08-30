//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/// @title NiftyApes interface for the admin role.
interface INiftyApesAdmin {
    function initialize(
        address newRoyaltiesEngineAddress,
        address newDelegateRegistryAddress,
        address newSeaportContractAddress,
        address newWethContractAddress,
        address newProtocolFeeRecipient
    ) external;

    /// @notice Pauses all interactions with the contract.
    ///         This is intended to be used as an emergency measure to avoid loosing funds.
    function pause() external;

    /// @notice Unpauses all interactions with the contract.
    function unpause() external;

    /// @notice Pauses sanctions checks
    function pauseSanctions() external;

    /// @notice Unpauses sanctions checks
    function unpauseSanctions() external;

    /// @notice Updates royalty engine contract address to new address
    /// @param newRoyaltyEngineContractAddress New royalty engine address
    function updateRoyaltiesEngineContractAddress(address newRoyaltyEngineContractAddress) external;

    /// @notice Updates delegate registry contract address to new address
    /// @param newDelegateRegistryContractAddress New delegate registry address
    function updateDelegateRegistryContractAddress(
        address newDelegateRegistryContractAddress
    ) external;

    /// @notice Updates seaport contract address to new address
    /// @param newSeaportContractAddress New seaport address
    function updateSeaportContractAddress(address newSeaportContractAddress) external;

    /// @notice Updates Weth contract address to new address
    /// @param newWethContractAddress New Weth contract address
    function updateWethContractAddress(address newWethContractAddress) external;

    /// @notice Returns value stored in `royaltiesEngineContractAddress`
    function royaltiesEngineContractAddress() external returns (address);

    /// @notice Returns value stored in `delegateRegistryContractAddress`
    function delegateRegistryContractAddress() external returns (address);

    /// @notice Returns value stored in `seaportContractAddress`
    function seaportContractAddress() external returns (address);

    /// @notice Returns value stored in `wethContractAddress`
    function wethContractAddress() external returns (address);

    /// @notice Updates protocol fee to a new value
    /// @param newProtocolFeeBPS New protocol fee basis points value
    function updateProtocolFeeBPS(uint96 newProtocolFeeBPS) external;

    /// @notice Updates protocol fee recipient address
    /// @param newProtocolFeeRecipient New protocol fee recipient address
    function updateProtocolFeeRecipient(address newProtocolFeeRecipient) external;

    /// @notice Returns current protocol fee basis points
    function protocolFeeBPS() external view returns (uint256);

    /// @notice Returns current protocol fee basis points
    function protocolFeeRecipient() external view returns (address);
}
