//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../storage/NiftyApesStorage.sol";
import "../../interfaces/niftyapes/lending/ILending.sol";
import "../../interfaces/niftyapes/INiftyApesErrors.sol";
import "../../interfaces/niftyapes/INiftyApesStructs.sol";
import "../../interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";
import "../../interfaces/sanctions/SanctionsList.sol";
import "../../interfaces/royaltyRegistry/IRoyaltyEngineV1.sol";
import "../../interfaces/delegateCash/IDelegationRegistry.sol";
import "../../interfaces/erc1155/IERC1155SupplyUpgradeable.sol";
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
    ERC1155HolderUpgradeable,
    INiftyApesErrors,
    INiftyApesStructs,
    ISellerFinancingEvents
{
    using AddressUpgradeable for address payable;
    using ERC165CheckerUpgradeable for address;
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
                    // need to update typeHash
                    NiftyApesStorage._OFFER_TYPEHASH,
                    offer.creator,
                    offer.offerType,
                    offer.item.itemType,
                    offer.item.token,
                    offer.item.identifier,
                    offer.item.amount,
                    offer.terms.itemType,
                    offer.terms.downPaymentAmount,
                    offer.terms.principalAmount,
                    offer.terms.minimumPrincipalPerPeriod,
                    offer.terms.periodInterestRateBps,
                    offer.terms.periodDuration,
                    offer.marketplaceRecipients,
                    offer.expiration,
                    offer.collectionOfferLimit,
                    offer.creatorOfferNonce
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

    function _getOfferSignatureStatus(bytes memory signature, NiftyApesStorage.SellerFinancingStorage storage sf) internal view returns (bool) {
        return sf.cancelledOrFinalized[signature];
    }

    function _getCollectionOfferCount(bytes memory signature, NiftyApesStorage.SellerFinancingStorage storage sf) internal view returns (uint64 count) {
        return sf.collectionOfferCounters[signature];
    }

    function _requireAvailableSignature(
        bytes memory signature,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view {
        if (sf.cancelledOrFinalized[signature]) {
            revert SignatureNotAvailable(signature);
        }
    }

    function _markSignatureUsed(
        Offer memory offer,
        bytes memory signature,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        sf.cancelledOrFinalized[signature] = true;
        emit OfferSignatureUsed(offer.item.token, offer.item.identifier, offer, signature);
    }
    
    function _commonLoanChecks(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (address lender) {
        // check for collection offer
        if (offer.item.identifier != ~uint256(0)) {
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


        // add check that offer.item.itemType is either 721 or 1155
        // add check that offer.terms.itemType is either NATIVE or 20
        _requireIsNotSanctioned(lender, sf);
        _requireIsNotSanctioned(borrower, sf);
        _requireIsNotSanctioned(msg.sender, sf);
        _requireOfferNotExpired(offer);
        // requireOfferisValid
        _requireNonZeroAddress(offer.item.token);

        // update this check, maybe not needed anymore? 
        if (IERC1155SupplyUpgradeable(offer.item.token).supportsInterface(type(IERC1155Upgradeable).interfaceId)) {
                _requireNonFungibleToken(
                    offer.item.token,
                    nftId
                );
            }        
            // require1MinsMinimumDuration
        if (offer.terms.periodDuration < 1 minutes) {
            revert InvalidPeriodDuration();
        }
        // requireNonZeroPrincipalAmount
        if (offer.terms.principalAmount == 0) {
            revert PrincipalAmountZero();
        }
        // requireMinimumPrincipalLessThanOrEqualToTotalPrincipal
        if (offer.terms.principalAmount < offer.terms.minimumPrincipalPerPeriod) {
            revert InvalidMinimumPrincipalPerPeriod(
                offer.terms.minimumPrincipalPerPeriod,
                offer.terms.principalAmount
            );
        }
        // requireNotSellerFinancingTicket
        if (offer.item.token == address(this)) {
            revert CannotBuySellerFinancingTicket();
        }
    }

    function _executeLoan(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        address lender,
        uint256 nftId,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        // instantiate loan
        Loan storage loan = _getLoan(sf.loanNonce, sf);

        // mint borrower nft
        _safeMint(borrower, sf.loanNonce);
        _setTokenURI(
            sf.loanNonce,
            IERC721MetadataUpgradeable(offer.item.token).tokenURI(nftId)
        );
        sf.loanNonce++;

        // mint lender nft
        _safeMint(lender, sf.loanNonce);
        sf.loanNonce++;

        // create loan
        _createLoan(loan, offer, nftId, sf.loanNonce - 1, sf.loanNonce - 2, sf);

        // add borrower delegate.cash delegation
        IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
            borrower,
            offer.item.token,
            nftId,
            true
        );

        // emit loan executed event
        emit LoanExecuted(offer.item.token, nftId, signature, loan);
    }

    function _createLoan(
        Loan storage loan,
        Offer memory offer,
        uint256 nftId,
        uint256 lenderNftId,
        uint256 borrowerNftId,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        loan.lenderNftId = lenderNftId;
        loan.borrowerNftId = borrowerNftId;
        loan.remainingPrincipal = uint128(offer.terms.principalAmount);
        loan.periodEndTimestamp = _currentTimestamp32() + offer.terms.periodDuration;
        loan.periodBeginTimestamp = _currentTimestamp32();
        loan.minimumPrincipalPerPeriod = offer.terms.minimumPrincipalPerPeriod;
        loan.periodInterestRateBps = offer.terms.periodInterestRateBps;
        loan.periodDuration = offer.terms.periodDuration;
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

    // can probably update to be more specific based in itemType
    function _transferCollateral(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        if (IERC1155SupplyUpgradeable(nftContractAddress).supportsInterface(type(IERC1155Upgradeable).interfaceId)) {
            _transferERC1155Token(
                nftContractAddress,
                nftId,
                from,
                to
            );
        } else {
            _transferNft(
                nftContractAddress,
                nftId,
                from,
                to
            );
        }
    }

    function _transferNft(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        IERC721Upgradeable(nftContractAddress).safeTransferFrom(from, to, nftId);
    }

    function _transferERC1155Token(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        IERC1155SupplyUpgradeable(nftContractAddress).safeTransferFrom(from, to, nftId, 1, bytes(""));
    }

    function _currentTimestamp32() internal view returns (uint32) {
        return SafeCastUpgradeable.toUint32(block.timestamp);
    }

    function _requireIsNotSanctioned(
        address addressToCheck,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view {
        if (!sf.sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(NiftyApesStorage.SANCTIONS_CONTRACT);
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

    function supportsInterface(bytes4 interfaceId) public pure  override(ERC1155ReceiverUpgradeable, ERC721Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId;
    }

    function _requireSigner(address signer, address expected) internal pure {
        if (signer != expected) {
            revert InvalidSigner(signer, expected);
        }
    }

        function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }


    function _requireExpectedOfferType(Offer memory offer, OfferType expectedOfferType) internal pure {
        if (offer.offerType != expectedOfferType) {
            revert InvalidOfferType(offer.offerType, expectedOfferType);
        }
    }

    function _getUnderlyingNft(
        uint256 loanNonce,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view returns (Item memory item) {
           Loan memory loan = _getLoan(loanNonce);
        return (loan.item);
    }

    // can supply the specific, even loanNonce or loanNonce + 1
    function _getLoan(
        uint256 loanNonce,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view returns (Loan storage) {
        if (loanNonce % 2 == 0 ){
            return sf.loans[loanNonce];
        } else {
            return sf.loans[loanNonce - 1];
        }
    }


    function _transfer(address from, address to, uint256 tokenId) internal override {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        _requireIsNotSanctioned(from, sf);
        _requireIsNotSanctioned(to, sf);
        // if the token is a borrower seller financing ticket
        if (tokenId % 2 == 0) {

            // need to update this underlying NFT and token delegation

            // get underlying nft
            Item memory item = _getUnderlyingNft(tokenId, sf);

            // remove from delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                from,
                item.token,
                item.identifier,
                false
            );

            // add to delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                to,
                item.token,
                item.identifier,
                true
            );
        }

        super._transfer(from, to, tokenId);
    }

    function _requireLoanNotInHardDefault(uint32 hardDefaultTimestamp) internal view {
        if (_currentTimestamp32() >= hardDefaultTimestamp) {
            revert SoftGracePeriodEnded();
        }
    }

    function _requireMsgSenderIsValidCaller(address expectedCaller) internal view {
        if (msg.sender != expectedCaller) {
            revert InvalidCaller(msg.sender, expectedCaller);
        }
    }
}
