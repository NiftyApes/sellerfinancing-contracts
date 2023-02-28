//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "../../interfaces/seaport/ISeaport.sol";
import "../../interfaces/sanctions/SanctionsList.sol";
import "../interfaces/IPurchaser.sol";

/// @notice Integration of Seaport to seller financing to allow purchase of NFT with financing
/// @title SeaportIntegration
/// @custom:version 1.0
/// @author captnseagraves (captnseagraves.eth)
/// @custom:contributor zishansami102 (zishansami.eth)
contract SeaportIntegration is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721HolderUpgradeable,
    PausableUpgradeable,
    IPurchaser
{
    using AddressUpgradeable for address payable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    address public seaportContractAddress;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting storage.
    uint256[500] private __gap;

    /// @notice The initializer for the marketplace integration contract.
    function initialize(
        address newSeaportContractAddress
    ) public initializer {
        seaportContractAddress = newSeaportContractAddress;

        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
    }


    function updateSeaportContractAddress(address newSeaportContractAddress)
        external
        onlyOwner
    {
        seaportContractAddress = newSeaportContractAddress;
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

    function purchase(
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external payable override nonReentrant returns (bool) {
        _requireIsNotSanctioned(msg.sender);
        // decode data
        (ISeaport.Order memory order, bytes32 fulfillerConduitKey) = abi.decode(data, (ISeaport.Order, bytes32));
        _validateOrder(order);

        uint256 considerationAmount = _calculateConsiderationAmount(order);

        // arrange asset amount from borrower side for the purchase
        require(msg.value >= considerationAmount, "Insufficient funds for purchase");
        if (msg.value > considerationAmount) {
            payable(msg.sender).sendValue(msg.value - considerationAmount);
        }
        require(
            ISeaport(seaportContractAddress).fulfillOrder{
                value: considerationAmount
            }(order, fulfillerConduitKey),
            "Seaport fulfill order request failed"
        );

        // approve the sellerFinancing contract for the purchased nft
        // validates that order and offer are for same NFT
        IERC721Upgradeable(nftContractAddress).approve(
            msg.sender,
            nftId
        );
        return true;
    }

    function _validateOrder(
        ISeaport.Order memory order
    ) internal pure {
        // requireOrderTokenERC721
        require(
            order.parameters.offer[0].itemType == ISeaport.ItemType.ERC721,
            "00049"
        );
        // requireOrderTokenAmount
        require(order.parameters.offer[0].startAmount == 1, "00049");
        // requireOrderNotAuction
        require(
            order.parameters.consideration[0].startAmount ==
                order.parameters.consideration[0].endAmount,
            "00049"
        );

        require(
            order.parameters.consideration[0].token == address(0),
            "order asset must be ETH"
        );
    }

    function _calculateConsiderationAmount(ISeaport.Order memory order)
        internal
        pure
        returns (uint256 considerationAmount)
    {
        for (
            uint256 i;
            i < order.parameters.totalOriginalConsiderationItems;

        ) {
            considerationAmount += order.parameters.consideration[i].endAmount;
            unchecked {
                ++i;
            }
        }
    }

    function _requireIsNotSanctioned(address addressToCheck) internal view {
        if (!_sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(SANCTIONS_CONTRACT);
            bool isToSanctioned = sanctionsList.isSanctioned(addressToCheck);
            require(!isToSanctioned, "00017");
        }
    }
}
