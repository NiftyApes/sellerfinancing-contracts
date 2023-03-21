//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/security/Pausable.sol";
import "../interfaces/sellerFinancing/ISellerFinancing.sol";
import "../interfaces/sanctions/SanctionsList.sol";

/// @title SuperRareIntegration
/// @custom:version 1.0
/// @author zishansami102 (zishansami.eth)

contract SuperRareIntegration is Ownable, Pausable {
    // using Address for address payable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @notice The base value for fees in the protocol.
    uint256 private constant MAX_BPS = 10_000;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    uint256 public marketplaceFeeBps;

    address public marketplaceFeeRecipient;

    address public sellerFinancingContractAddress;

    error ZeroAddress();

    error InsufficientMsgValue(uint256 given, uint256 expected);

    error ConditionSendValueFailed(address from, address to, uint256 amount);

    error SanctionedAddress(address account);

    constructor(
        address _sellerFinancingContractAddress,
        address _marketplaceFeeRecipient,
        uint256 _marketplaceFeeBps
    ) {
        _requireNonZeroAddress(_sellerFinancingContractAddress);
        _requireNonZeroAddress(_marketplaceFeeRecipient);

        sellerFinancingContractAddress = _sellerFinancingContractAddress;
        marketplaceFeeRecipient = _marketplaceFeeRecipient;
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
    function updateMarketplaceFeeRecipient(
        address newMarketplaceFeeRecipient
    ) external onlyOwner {
        _requireNonZeroAddress(newMarketplaceFeeRecipient);
        marketplaceFeeRecipient = newMarketplaceFeeRecipient;
    }

    /// @param newMarketplaceFeeBps New value for marketplaceFeeBps
    function updateMarketplaceFeeBps(
        uint256 newMarketplaceFeeBps
    ) external onlyOwner {
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
        address buyer
    ) external payable whenNotPaused {
        _requireIsNotSanctioned(msg.sender);

        uint256 marketplaceFeeAmount = (offer.price * marketplaceFeeBps) /
            MAX_BPS;
        if (msg.value < offer.downPaymentAmount + marketplaceFeeAmount) {
            revert InsufficientMsgValue(
                msg.value,
                offer.downPaymentAmount + marketplaceFeeAmount
            );
        }
        _conditionalSendValue(
            marketplaceFeeRecipient,
            msg.sender,
            marketplaceFeeAmount
        );

        ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing{
            value: msg.value - marketplaceFeeAmount
        }(offer, signature, buyer);
    }

    /// @dev If "to" is a contract that doesnt except ETH, send value back to "from" or revert
    function _conditionalSendValue(
        address to,
        address from,
        uint256 amount
    ) internal {
        (bool toSuccess, ) = to.call{value: amount}("");

        if (!toSuccess) {
            (bool fromSuccess, ) = from.call{value: amount}("");
            // require ETH is sucessfully sent to either to or from
            // we do not want ETH hanging in contract.
            if (!fromSuccess) {
                revert ConditionSendValueFailed(from, to, amount);
            }
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
