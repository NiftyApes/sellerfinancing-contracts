//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/offerManagement/IOfferManagement.sol";
import "./common/NiftyApesInternal.sol";

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
