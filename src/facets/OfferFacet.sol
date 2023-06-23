//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/offerManagement/IOfferManagement.sol";
import "../interfaces/sanctions/SanctionsList.sol";
import "../interfaces/royaltyRegistry/IRoyaltyEngineV1.sol";
import "../interfaces/delegateCash/IDelegationRegistry.sol";
import "../interfaces/seaport/ISeaport.sol";
import "../lib/ECDSABridge.sol";
import "./common/NiftyApesInternal.sol";
import { LibDiamond } from "../diamond/libraries/LibDiamond.sol";

/// @title NiftyApes Seller Financing facet
/// @custom:version 2.0
/// @author captnseagraves (captnseagraves.eth)
/// @custom:contributor zishansami102 (zishansami.eth)
/// @custom:contributor zjmiller (zjmiller.eth)
contract NiftyApesOfferFacet is
    NiftyApesInternal,
    IOfferManagement
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @inheritdoc IOfferManagement
    function getOfferHash(Offer memory offer) public view returns (bytes32) {
    return _getOfferHash(offer);
    }

    /// @inheritdoc IOfferManagement
    function getOfferSigner(
        Offer memory offer,
        bytes memory signature
    ) public view override returns (address) {
        return _getOfferSigner(offer, signature);
    }

    /// @inheritdoc IOfferManagement
    function getOfferSignatureStatus(bytes memory signature) external view returns (bool) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getOfferSignatureStatus(signature, sf);
    }

    /// @inheritdoc IOfferManagement
    function getCollectionOfferCount(bytes memory signature) public view returns (uint64 count) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getCollectionOfferCount(signature, sf);
    }

    /// @inheritdoc IOfferManagement
    function withdrawOfferSignature(Offer memory offer, bytes memory signature) external {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        _requireAvailableSignature(signature, sf);
        address signer = _getOfferSigner(offer, signature);
        _requireSigner(signer, msg.sender);
        _markSignatureUsed(offer, signature, sf);
    }

    /// @inheritdoc IOfferManagement
    function withdrawAllOffers() external {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.offerNonce[msg.sender] += 1;
    }
}
