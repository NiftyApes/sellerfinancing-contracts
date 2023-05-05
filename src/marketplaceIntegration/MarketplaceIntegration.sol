//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/security/Pausable.sol";
import "@openzeppelin-norm/contracts/utils/Address.sol";
import "../interfaces/sellerFinancing/ISellerFinancing.sol";
import "../interfaces/sanctions/SanctionsList.sol";

/// @title MarketplaceIntegration
/// @custom:version 1.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)

contract MarketplaceIntegration is Ownable, Pausable {
    using Address for address payable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @notice The base value for fees in the protocol.
    uint256 private constant BASE_BPS = 10_000;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    uint256 public marketplaceFeeBps;

    address payable public marketplaceFeeRecipient;

    address public sellerFinancingContractAddress;

    error ZeroAddress();

    error InsufficientMsgValue(uint256 given, uint256 expected);

    error SanctionedAddress(address account);

    error InvalidInputLength();

    error BuyWithFinancingCallRevertedAt(uint256 index);

    constructor(
        address _sellerFinancingContractAddress,
        address _marketplaceFeeRecipient,
        uint256 _marketplaceFeeBps
    ) {
        _requireNonZeroAddress(_sellerFinancingContractAddress);
        _requireNonZeroAddress(_marketplaceFeeRecipient);

        sellerFinancingContractAddress = _sellerFinancingContractAddress;
        marketplaceFeeRecipient = payable(_marketplaceFeeRecipient);
        marketplaceFeeBps = _marketplaceFeeBps;
    }

    /// @param newSellerFinancingContractAddress New address for SellerFinancing contract
    function updateSellerFinancingContractAddress(
        address newSellerFinancingContractAddress
    ) external onlyOwner {
        _requireNonZeroAddress(newSellerFinancingContractAddress);
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
    }

    /// @param newMarketplaceFeeRecipient New address for MarketplaceFeeRecipient
    function updateMarketplaceFeeRecipient(address newMarketplaceFeeRecipient) external onlyOwner {
        _requireNonZeroAddress(newMarketplaceFeeRecipient);
        marketplaceFeeRecipient = payable(newMarketplaceFeeRecipient);
    }

    /// @param newMarketplaceFeeBps New value for marketplaceFeeBps
    function updateMarketplaceFeeBps(uint256 newMarketplaceFeeBps) external onlyOwner {
        marketplaceFeeBps = newMarketplaceFeeBps;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function pauseSanctions() external onlyOwner {
        _sanctionsPause = true;
    }

    function unpauseSanctions() external onlyOwner {
        _sanctionsPause = false;
    }

    function buyWithFinancing(
        ISellerFinancing.Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 nftId
    ) external payable whenNotPaused {
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        uint256 marketplaceFeeAmount = (offer.price * marketplaceFeeBps) / BASE_BPS;
        if (msg.value < offer.downPaymentAmount + marketplaceFeeAmount) {
            revert InsufficientMsgValue(msg.value, offer.downPaymentAmount + marketplaceFeeAmount);
        }
        marketplaceFeeRecipient.sendValue(marketplaceFeeAmount);

        ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing{
            value: msg.value - marketplaceFeeAmount
        }(offer, signature, buyer, nftId);
    }

    function buyWithFinancingBatch(
        ISellerFinancing.Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata nftIds,
        bool partialExecution
    ) external payable whenNotPaused {
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        if(offers.length != signatures.length || offers.length != nftIds.length) {
            revert InvalidInputLength();
        }

        uint256 marketplaceFeeAccumulated;
        uint256 valueConsumed;
        for (uint256 i = 0; i < offers.length; ++i) {
            ISellerFinancing.Offer memory offer = offers[i];
            uint256 marketplaceFeeAmount = (offer.price * marketplaceFeeBps) / BASE_BPS;
            // check if value remained not enough for executing current offer
            // and if not, then break for partialExecution else revert
            if (msg.value - valueConsumed < offer.downPaymentAmount + marketplaceFeeAmount + marketplaceFeeAccumulated) {
                if (partialExecution) {
                    break;
                } else {
                    revert InsufficientMsgValue(msg.value, valueConsumed + offer.downPaymentAmount + marketplaceFeeAmount + marketplaceFeeAccumulated);
                }
            }
            // try executing current offer and update `marketplaceFeeAccumulated` and `valueConsumed`
            // if failed, then then revert if partial execution is not allowed.
            try ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing{
                value: offer.downPaymentAmount
            } (offer, signatures[i], buyer, nftIds[i]) {
                marketplaceFeeAccumulated = marketplaceFeeAccumulated + marketplaceFeeAmount;
                valueConsumed = valueConsumed + offer.downPaymentAmount;
            } catch {
                if(!partialExecution) {
                    revert BuyWithFinancingCallRevertedAt(i);
                }
            }
        }
        marketplaceFeeRecipient.sendValue(marketplaceFeeAccumulated);
        if (msg.value - valueConsumed - marketplaceFeeAccumulated > 0) {
            payable(msg.sender).sendValue(msg.value - valueConsumed - marketplaceFeeAccumulated);
        }
    }


    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }

    function _requireIsNotSanctioned(address addressToCheck) internal view {
        if (!_sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(SANCTIONS_CONTRACT);
            bool isToSanctioned = sanctionsList.isSanctioned(addressToCheck);
            if (isToSanctioned) {
                revert SanctionedAddress(addressToCheck);
            }
        }
    }
}
