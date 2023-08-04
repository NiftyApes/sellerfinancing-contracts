//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/INiftyApesAdmin.sol";
import "./common/NiftyApesInternal.sol";
import { LibDiamond } from "../diamond/libraries/LibDiamond.sol";

/// @title NiftyApes Admin facet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract NiftyApesAdminFacet is
    NiftyApesInternal,
    INiftyApesAdmin
{
    using AddressUpgradeable for address payable;
    /// @notice The initializer for the NiftyApes protocol.
    ///         NiftyApes is intended to be deployed as one of the facets to a diamond and thus needs to initialize
    ///         its state outside of a constructor.
    function initialize(
        address newRoyaltiesEngineContractAddress,
        address newDelegateRegistryContractAddress,
        address newSeaportContractAddress,
        address newWethContractAddress,
        address newProtocolFeeRecipient
    ) public initializer {
        _requireNonZeroAddress(newRoyaltiesEngineContractAddress);
        _requireNonZeroAddress(newDelegateRegistryContractAddress);
        _requireNonZeroAddress(newSeaportContractAddress);
        _requireNonZeroAddress(newWethContractAddress);
        _requireNonZeroAddress(newProtocolFeeRecipient);

        EIP712Upgradeable.__EIP712_init("NiftyApes_SellerFinancing", "0.0.1");
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
        ERC721Upgradeable.__ERC721_init("NiftyApes Seller Financing Tickets", "BANANAS");
        ERC721URIStorageUpgradeable.__ERC721URIStorage_init();
        ERC1155HolderUpgradeable.__ERC1155Holder_init();

        // manually setting interfaceIds to be true,
        // since we have an independent supportsInterface in diamondLoupe facet
        // and has a separate mapping storage to mark the supported interfaces as true
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC721Upgradeable).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721MetadataUpgradeable).interfaceId] = true;
        ds.supportedInterfaces[type(IERC1155Upgradeable).interfaceId] = true;
        ds.supportedInterfaces[type(IERC1155MetadataURIUpgradeable).interfaceId] = true;

        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();

        sf.royaltiesEngineContractAddress = newRoyaltiesEngineContractAddress;
        sf.delegateRegistryContractAddress = newDelegateRegistryContractAddress;
        sf.seaportContractAddress = newSeaportContractAddress;
        sf.wethContractAddress = newWethContractAddress;
        sf.protocolFeeRecipient = payable(newProtocolFeeRecipient);
    }

    /// @inheritdoc INiftyApesAdmin
    function updateRoyaltiesEngineContractAddress(
        address newRoyaltiesEngineContractAddress
    ) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newRoyaltiesEngineContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.royaltiesEngineContractAddress = newRoyaltiesEngineContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function updateDelegateRegistryContractAddress(
        address newDelegateRegistryContractAddress
    ) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newDelegateRegistryContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.delegateRegistryContractAddress = newDelegateRegistryContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function updateSeaportContractAddress(address newSeaportContractAddress) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newSeaportContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.seaportContractAddress = newSeaportContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function updateWethContractAddress(address newWethContractAddress) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newWethContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.wethContractAddress = newWethContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function royaltiesEngineContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.royaltiesEngineContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function delegateRegistryContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.delegateRegistryContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function seaportContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.seaportContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function wethContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.wethContractAddress;
    }

    /// @inheritdoc INiftyApesAdmin
    function pause() external {
        LibDiamond.enforceIsContractOwner();
        _pause();
    }

    /// @inheritdoc INiftyApesAdmin
    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        _unpause();
    }

    /// @inheritdoc INiftyApesAdmin
    function pauseSanctions() external {
        LibDiamond.enforceIsContractOwner();
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.sanctionsPause = true;
    }

    /// @inheritdoc INiftyApesAdmin
    function unpauseSanctions() external {
        LibDiamond.enforceIsContractOwner();
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.sanctionsPause = false;
    }

    /// @inheritdoc INiftyApesAdmin
    function updateProtocolFeeBPS(uint96 newProtocolFeeBPS) external {
        LibDiamond.enforceIsContractOwner();
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.protocolFeeBPS = newProtocolFeeBPS;
    }

    /// @inheritdoc INiftyApesAdmin
    function protocolFeeBPS() external view returns(uint256) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.protocolFeeBPS;
    }

    /// @inheritdoc INiftyApesAdmin
    function updateProtocolFeeRecipient(address newProtocolFeeRecipient) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newProtocolFeeRecipient);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.protocolFeeRecipient = payable(newProtocolFeeRecipient);
    }

    /// @inheritdoc INiftyApesAdmin
    function protocolFeeRecipient() external view returns(address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.protocolFeeRecipient;
    }
}
