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
import "@openzeppelin/contracts/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../storage/NiftyApesStorage.sol";
import "../../interfaces/niftyapes/INiftyApesErrors.sol";
import "../../interfaces/niftyapes/INiftyApesStructs.sol";
import "../../interfaces/niftyapes/INiftyApesEvents.sol";
import "../../interfaces/sanctions/SanctionsList.sol";
import "../../interfaces/royaltyRegistry/IRoyaltyEngineV1.sol";
import "../../interfaces/delegateCash/IDelegationRegistry.sol";
import "../../lib/ECDSABridge.sol";

/// @title NiftyApes abstract contract for common internal functions
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
abstract contract NiftyApesInternal is
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    PausableUpgradeable,
    ERC721HolderUpgradeable,
    ERC721URIStorageUpgradeable,
    INiftyApesErrors,
    INiftyApesStructs,
    INiftyApesEvents
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev This empty reserved space is put in place for any variables 
    ///      that may get added as part of any additional imports in future updates
    uint256[1000] private __gap;

    /// @dev Empty constructor ensures no 3rd party can call initialize before the NiftyApes team on this facet contract.
    constructor() initializer {}

    function _getOfferHash(Offer memory offer) internal view returns (bytes32) {
        bytes32 collateralItemHash = keccak256(
            abi.encode(
                NiftyApesStorage._COLLATERAL_ITEM_TYPEHASH,
                offer.collateralItem.itemType,
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                offer.collateralItem.amount
            )
        );

        bytes32 loanTermsHash = keccak256(
            abi.encode(
                NiftyApesStorage._LOAN_TERMS_TYPEHASH,
                offer.loanTerms.itemType,
                offer.loanTerms.token,
                offer.loanTerms.tokenId,
                offer.loanTerms.principalAmount,
                offer.loanTerms.minimumPrincipalPerPeriod,
                offer.loanTerms.downPaymentAmount,
                offer.loanTerms.periodInterestRateBps,
                offer.loanTerms.periodDuration
            )
        );

        // Creating a hash for each MarketplaceRecipient
        bytes32[] memory marketplaceRecipientHashes = new bytes32[](offer.marketplaceRecipients.length);
        for (uint i; i < offer.marketplaceRecipients.length; ++i) {
            marketplaceRecipientHashes[i] = keccak256(
                abi.encode(
                    NiftyApesStorage._MARKETPLACE_RECIPIENT_TYPEHASH,
                    offer.marketplaceRecipients[i].recipient,
                    offer.marketplaceRecipients[i].amount
                )
            );
        }
        // Generate a final hash for the array of MarketplaceRecipient by hashing the concatenation of all hashes
        bytes32 marketplaceRecipientsHash = keccak256(abi.encodePacked(marketplaceRecipientHashes));

        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    NiftyApesStorage._OFFER_TYPEHASH,
                    offer.offerType,
                    collateralItemHash,
                    loanTermsHash,
                    offer.creator,
                    offer.expiration,
                    offer.isCollectionOffer,
                    offer.collectionOfferLimit,
                    offer.creatorOfferNonce,
                    offer.payRoyalties,
                    marketplaceRecipientsHash
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
        emit OfferSignatureUsed(offer.collateralItem.token, offer.collateralItem.tokenId, offer, signature);
    }
    
    function _commonLoanChecks(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 tokenId,
        uint256 tokenAmount,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (address lender) {
        if (!offer.isCollectionOffer) {
            if (tokenId != offer.collateralItem.tokenId) {
                revert CollateralDetailsMustMatch();
            }
            if (offer.collateralItem.itemType == ItemType.ERC1155 && tokenAmount != offer.collateralItem.amount) {
                revert CollateralDetailsMustMatch();
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

        // loan item must be either ETH or ERC20
        if (offer.loanTerms.itemType != ItemType.NATIVE || offer.loanTerms.itemType != ItemType.ERC20) {
            revert InvalidLoanItemType();
        }

        // get lender
        lender = _getOfferSigner(offer, signature);
        if (_callERC1271isValidSignature(offer.creator, _getOfferHash(offer), signature)) {
            lender = offer.creator;
        }

        _requireValidOfferNonce(offer, lender, sf);
        _requireIsNotSanctioned(lender, sf);
        _requireIsNotSanctioned(borrower, sf);
        _requireIsNotSanctioned(msg.sender, sf);
        _requireOfferNotExpired(offer);
        // requireOfferisValid
        _requireNonZeroAddress(offer.collateralItem.token);
        // require1MinsMinimumDuration
        if (offer.loanTerms.periodDuration < 1 minutes) {
            revert InvalidPeriodDuration();
        }
        // requireNonZeroPrincipalAmount
        if (offer.loanTerms.principalAmount == 0) {
            revert PrincipalAmountZero();
        }
        // requireMinimumPrincipalLessThanOrEqualToTotalPrincipal
        if (offer.loanTerms.principalAmount < offer.loanTerms.minimumPrincipalPerPeriod) {
            revert InvalidMinimumPrincipalPerPeriod(
                offer.loanTerms.minimumPrincipalPerPeriod,
                offer.loanTerms.principalAmount
            );
        }
        // requireNotSellerFinancingTicket
        if (offer.collateralItem.token == address(this)) {
            revert CannotBuySellerFinancingTicket();
        }
    }

    function _executeLoan(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        address lender,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        // instantiate loan
        Loan storage loan = _getLoan(sf.loanId, sf);

        if (offer.collateralItem.itemType == ItemType.ERC721) {
            _setTokenURI(
                sf.loanId,
                IERC721MetadataUpgradeable(offer.collateralItem.token).tokenURI(offer.collateralItem.tokenId)
            );
            // add borrower delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                borrower,
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                true
            );
        }

        // mint borrower token
        _safeMint(borrower, sf.loanId);
        sf.loanId++;

        // mint lender token
        _safeMint(lender, sf.loanId);
        sf.loanId++;

        // create loan
        _createLoan(loan, offer, sf.loanId - 2);

        // emit loan executed event
        emit LoanExecuted(offer.collateralItem.token, offer.collateralItem.tokenId, offer.collateralItem.amount, signature, loan);
    }

    function _createLoan(
        Loan storage loan,
        Offer memory offer,
        uint256 loanId
    ) internal {
        loan.loanId = loanId;
        loan.collateralItem.itemType = offer.collateralItem.itemType;
        loan.collateralItem.token = offer.collateralItem.token;
        loan.collateralItem.tokenId = offer.collateralItem.tokenId;
        loan.collateralItem.amount = offer.collateralItem.amount;

        loan.loanTerms.itemType = offer.loanTerms.itemType;
        loan.loanTerms.principalAmount = uint128(offer.loanTerms.principalAmount);
        loan.loanTerms.minimumPrincipalPerPeriod = offer.loanTerms.minimumPrincipalPerPeriod;

        loan.periodEndTimestamp = _currentTimestamp32() + offer.loanTerms.periodDuration;
        loan.periodBeginTimestamp = _currentTimestamp32();
        loan.loanTerms.periodInterestRateBps = offer.loanTerms.periodInterestRateBps;
        loan.loanTerms.periodDuration = offer.loanTerms.periodDuration;
        if (offer.offerType == OfferType.SELLER_FINANCING) {
            loan.payRoyalties = offer.payRoyalties;
        }
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

    function _transferCollateral(
        CollateralItem memory collateralItem,
        address from,
        address to
    ) internal {
        if (collateralItem.itemType == ItemType.ERC1155) {
            _transferERC1155Token(
                collateralItem.token,
                from,
                to,
                collateralItem.tokenId,
                collateralItem.amount
            );
        } else if (collateralItem.itemType == ItemType.ERC721) {
            _transferNft(
                collateralItem.token,
                from,
                to,
                collateralItem.tokenId
            );
        } else if (collateralItem.itemType == ItemType.ERC20) {
            _transferERC20(
                collateralItem.token,
                from,
                to,
                collateralItem.amount
            );
        } else {
            revert InvalidCollateralItemType();
        }
    }

    function _transferNft(
        address token,
        address from,
        address to,
        uint256 tokenId
    ) internal {
        IERC721Upgradeable(token).safeTransferFrom(from, to, tokenId);
    }

    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        IERC20Upgradeable(token).safeTransferFrom(from, to, amount);
    }

    function _transferERC1155Token(
        address token,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal {
        IERC1155Upgradeable(token).safeTransferFrom(from, to, tokenId, amount, bytes(""));
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

    // can supply the specific, even loanId or loanId + 1
    function _getLoan(
        uint256 loanId,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view returns (Loan storage) {
        if (loanId % 2 == 0 ){
            return sf.loans[loanId];
        } else {
            return sf.loans[loanId - 1];
        }
    }

    function _requireExpectedOfferType(Offer memory offer, OfferType expectedOfferType) internal pure {
        if (offer.offerType != expectedOfferType) {
            revert InvalidOfferType(offer.offerType, expectedOfferType);
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        _requireIsNotSanctioned(from, sf);
        _requireIsNotSanctioned(to, sf);
        // if the token is a borrower ticket
        if (tokenId % 2 == 0) {
            // get underlying token
            Loan memory loan = _getLoan(tokenId, sf);

            // remove from delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                from,
                loan.collateralItem.token,
                loan.collateralItem.tokenId,
                false
            );

            // add to delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                to,
                loan.collateralItem.token,
                loan.collateralItem.tokenId,
                true
            );
        }

        super._transfer(from, to, tokenId);
    }

    function _payRoyalties(
        address nftContractAddress,
        uint256 nftId,
        address from,
        ItemType paymentItemType,
        address paymentToken,
        uint256 paymentAmount,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (uint256 totalRoyaltiesPaid) {
        // query royalty recipients and amounts
        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            sf.royaltiesEngineContractAddress
        ).getRoyaltyView(nftContractAddress, nftId, paymentAmount);

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                if (paymentItemType == ItemType.NATIVE) {
                    _conditionalSendValue(recipients[i], from, amounts[i], sf);
                } else {
                    _transferERC20(paymentToken, from, recipients[i], amounts[i]);
                }
                totalRoyaltiesPaid += amounts[i];
            }
        }
    }

    /// @dev If "to" is a contract that doesn't accept ETH, send value back to "from" and continue
    /// otherwise "to" could force a default by sending bearer token to contract that does not accept ETH
    function _conditionalSendValue(
        address to,
        address from,
        uint256 amount,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        if (address(this).balance < amount) {
            revert InsufficientBalance(amount, address(this).balance);
        }

        // check if to is sanctioned
        bool isToSanctioned;
        if (!sf.sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(NiftyApesStorage.SANCTIONS_CONTRACT);
            isToSanctioned = sanctionsList.isSanctioned(to);
        }

        // if sanctioned, return value to from
        if (isToSanctioned) {
            (bool fromSuccess, ) = from.call{ value: amount }("");
            // require ETH is successfully sent to either to or from
            // we do not want ETH hanging in contract.
            if (!fromSuccess) {
                revert ConditionSendValueFailed(from, to, amount);
            }
        } else {
            // attempt to send value to to
            (bool toSuccess, ) = to.call{ value: amount }("");

            // if send fails, return vale to from
            if (!toSuccess) {
                (bool fromSuccess, ) = from.call{ value: amount }("");
                // require ETH is successfully sent to either to or from
                // we do not want ETH hanging in contract.
                if (!fromSuccess) {
                    revert ConditionSendValueFailed(from, to, amount);
                }
            }
        }
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

    function _requireValidOfferNonce(
        Offer memory offer,
        address lender,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view {
        if (offer.creatorOfferNonce != sf.offerNonce[lender]) {
            revert InvalidOfferNonce(offer.creatorOfferNonce, sf.offerNonce[lender]);
        }
    }

    function _requireLoanItemWETH(
            LoanTerms memory loanTerms,
            NiftyApesStorage.SellerFinancingStorage storage sf
        ) internal {
        if (loanTerms.itemType != ItemType.ERC20) {
            revert InvalidLoanItemType();
        }
        if (loanTerms.token != sf.wethContractAddress) {
            revert InvalidLoanItemToken(loanTerms.token);
        }
    }
}
