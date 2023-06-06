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
import "../../storage/StorageA.sol";
import "../../interfaces/niftyapes/lending/ILending.sol";
import "../../interfaces/niftyapes/sellerFinancing/ISellerFinancingErrors.sol";
import "../../interfaces/niftyapes/sellerFinancing/ISellerFinancingStructs.sol";
import "../../interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";
import "../../interfaces/sanctions/SanctionsList.sol";
import "../../interfaces/royaltyRegistry/IRoyaltyEngineV1.sol";
import "../../interfaces/delegateCash/IDelegationRegistry.sol";
import "../../lib/ECDSABridge.sol";
import { LibDiamond } from "../../diamond/libraries/LibDiamond.sol";

/// @title NiftyApes abstract contract for common internal functions
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
abstract contract NiftyApesInternal is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721HolderUpgradeable,
    ISellerFinancingErrors,
    ISellerFinancingStructs,
    ISellerFinancingEvents
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev This empty reserved space is put in place for any variables 
    ///      that may get added as part of any additional imports in future updates
    uint256[1000] private __gap;

    /// @dev Empty constructor ensures no 3rd party can call initialize before the NiftyApes team on this facet contract.
    constructor() initializer {}

    function _getOfferHash(Offer memory offer) internal view returns (bytes32) {
    return
        _hashTypedDataV4(
            keccak256(
                abi.encode(
                    StorageA._OFFER_TYPEHASH,
                    offer.offerType,
                    offer.downPaymentAmount,
                    offer.principalAmount,
                    offer.minimumPrincipalPerPeriod,
                    offer.nftId,
                    offer.nftContractAddress,
                    offer.periodInterestRateBps,
                    offer.periodDuration,
                    offer.expiration,
                    offer.creator,
                    offer.isCollectionOffer,
                    offer.collectionOfferLimit
                )
            )
        );
    }

    function _getOfferSigner(
        Offer memory offer,
        bytes memory signature
    ) internal view returns (address) {
        return ECDSABridge.recover(_getOfferHash(offer), signature);
    }

    function _getOfferSignatureStatus(bytes memory signature, StorageA.SellerFinancingStorage storage sf) internal view returns (bool) {
        return sf.cancelledOrFinalized[signature];
    }

    function _getCollectionOfferCount(bytes memory signature, StorageA.SellerFinancingStorage storage sf) internal view returns (uint64 count) {
        return sf.collectionOfferCounters[signature];
    }

    function _requireAvailableSignature(
        bytes memory signature,
        StorageA.SellerFinancingStorage storage sf
    ) internal view {
        if (sf.cancelledOrFinalized[signature]) {
            revert SignatureNotAvailable(signature);
        }
    }

    function _markSignatureUsed(
        Offer memory offer,
        bytes memory signature,
        StorageA.SellerFinancingStorage storage sf
    ) internal {
        sf.cancelledOrFinalized[signature] = true;
        emit OfferSignatureUsed(offer.nftContractAddress, offer.nftId, offer, signature);
    }
    
    function _commonLoanChecks(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId,
        StorageA.SellerFinancingStorage storage sf
    ) internal returns (address lender) {
        // check for collection offer
        if (!offer.isCollectionOffer) {
            if (nftId != offer.nftId) {
                revert NftIdsMustMatch();
            }
            _requireAvailableSignature(signature, sf);
            // mark signature as used
            _markSignatureUsed(offer, signature, sf);
        } else {
            if (sf.collectionOfferCounters[signature] >= offer.collectionOfferLimit) {
                revert CollectionOfferLimitReached();
            }
            sf.collectionOfferCounters[signature] += 1;
        }

        // get lender
        lender = _getOfferSigner(offer, signature);
        if (_callERC1271isValidSignature(offer.creator, _getOfferHash(offer), signature)) {
            lender = offer.creator;
        }

        _requireIsNotSanctioned(lender, sf);
        _requireIsNotSanctioned(borrower, sf);
        _requireIsNotSanctioned(msg.sender, sf);
        _requireOfferNotExpired(offer);
        // requireOfferisValid
        _requireNonZeroAddress(offer.nftContractAddress);
        // require1MinsMinimumDuration
        if (offer.periodDuration < 1 minutes) {
            revert InvalidPeriodDuration();
        }
        // requireNonZeroPrincipalAmount
        if (offer.principalAmount == 0) {
            revert PrincipalAmountZero();
        }
        // requireMinimumPrincipalLessThanOrEqualToTotalPrincipal
        if (offer.principalAmount < offer.minimumPrincipalPerPeriod) {
            revert InvalidMinimumPrincipalPerPeriod(
                offer.minimumPrincipalPerPeriod,
                offer.principalAmount
            );
        }
        // requireNotSellerFinancingTicket
        if (offer.nftContractAddress == address(this)) {
            revert CannotBuySellerFinancingTicket();
        }
    }

    function _executeLoan(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        address lender,
        uint256 nftId,
        StorageA.SellerFinancingStorage storage sf
    ) internal {
        // instantiate loan
        Loan storage loan = _getLoan(offer.nftContractAddress, nftId, sf);

        // mint borrower nft
        _safeMint(borrower, sf.loanNftNonce);
        _setTokenURI(
            sf.loanNftNonce,
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );
        sf.loanNftNonce++;

        // mint lender nft
        _safeMint(lender, sf.loanNftNonce);
        sf.loanNftNonce++;

        // create loan
        _createLoan(loan, offer, nftId, sf.loanNftNonce - 1, sf.loanNftNonce - 2, sf);

        // add borrower delegate.cash delegation
        IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
            borrower,
            offer.nftContractAddress,
            nftId,
            true
        );

        // emit loan executed event
        emit LoanExecuted(offer.nftContractAddress, nftId, signature, loan);
    }

    function _createLoan(
        Loan storage loan,
        Offer memory offer,
        uint256 nftId,
        uint256 lenderNftId,
        uint256 borrowerNftId,
        StorageA.SellerFinancingStorage storage sf
    ) internal {
        loan.lenderNftId = lenderNftId;
        loan.borrowerNftId = borrowerNftId;
        loan.remainingPrincipal = uint128(offer.principalAmount);
        loan.periodEndTimestamp = _currentTimestamp32() + offer.periodDuration;
        loan.periodBeginTimestamp = _currentTimestamp32();
        loan.minimumPrincipalPerPeriod = offer.minimumPrincipalPerPeriod;
        loan.periodInterestRateBps = offer.periodInterestRateBps;
        loan.periodDuration = offer.periodDuration;

        // instantiate underlying nft pointer
        UnderlyingNft storage buyerUnderlyingNft = _getUnderlyingNft(borrowerNftId, sf);
        // set underlying nft values
        buyerUnderlyingNft.nftContractAddress = offer.nftContractAddress;
        buyerUnderlyingNft.nftId = nftId;

        // instantiate underlying nft pointer
        UnderlyingNft storage sellerUnderlyingNft = _getUnderlyingNft(lenderNftId, sf);
        // set underlying nft values
        sellerUnderlyingNft.nftContractAddress = offer.nftContractAddress;
        sellerUnderlyingNft.nftId = nftId;
    }

    function _callERC1271isValidSignature(
        address _addr,
        bytes32 _hash,
        bytes calldata _signature
    ) internal returns (bool) {
        (, bytes memory data) = _addr.call(
            abi.encodeWithSignature("isValidSignature(bytes32,bytes)", _hash, _signature)
        );
        return bytes4(data) == 0x1626ba7e;
    }

    function _transferNft(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        IERC721Upgradeable(nftContractAddress).safeTransferFrom(from, to, nftId);
    }

    function _currentTimestamp32() internal view returns (uint32) {
        return SafeCastUpgradeable.toUint32(block.timestamp);
    }

    function _requireIsNotSanctioned(
        address addressToCheck,
        StorageA.SellerFinancingStorage storage sf
    ) internal view {
        if (!sf.sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(StorageA.SANCTIONS_CONTRACT);
            bool isToSanctioned = sanctionsList.isSanctioned(addressToCheck);
            if (isToSanctioned) {
                revert SanctionedAddress(addressToCheck);
            }
        }
    }

    function _requireOfferNotExpired(Offer memory offer) internal view {
        if (offer.expiration <= SafeCastUpgradeable.toUint32(block.timestamp)) {
            revert OfferExpired();
        }
    }

    function _require721Owner(
        address nftContractAddress,
        uint256 nftId,
        address nftOwner
    ) internal view {
        if (IERC721Upgradeable(nftContractAddress).ownerOf(nftId) != nftOwner) {
            revert NotNftOwner(nftContractAddress, nftId, nftOwner);
        }
    }

    function _requireSigner(address signer, address expected) internal pure {
        if (signer != expected) {
            revert InvalidSigner(signer, expected);
        }
    }

    function _getUnderlyingNft(
        uint256 niftyApesTicketId,
        StorageA.SellerFinancingStorage storage sf
    ) internal view returns (UnderlyingNft storage) {
        return sf.underlyingNfts[niftyApesTicketId];
    }

    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }

    function _getLoan(
        address nftContractAddress,
        uint256 nftId,
        StorageA.SellerFinancingStorage storage sf
    ) internal view returns (Loan storage) {
        return sf.loans[nftContractAddress][nftId];
    }

    function _requireExpectedOfferType(Offer memory offer, OfferType expectedOfferType) internal pure {
        if (offer.offerType != expectedOfferType) {
            revert InvalidOfferType(offer.offerType, expectedOfferType);
        }
    }
}
