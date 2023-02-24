//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../interfaces/sellerFinancing/ISellerFinancing.sol";
import "../interfaces/seaport/ISeaport.sol";
import "../interfaces/sanctions/SanctionsList.sol";

/// @notice Integration of Seaport to seller financing to allow purchase of NFT with financing
/// @title buyOnSeaportIntegration
/// @custom:version 1.0
/// @author captnseagraves (captnseagraves.eth)
/// @custom:contributor zishansami102 (zishansami.eth)
contract BuyOnSeaportIntegration is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721HolderUpgradeable,
    PausableUpgradeable
{
    using AddressUpgradeable for address payable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    address public offersContractAddress;

    address public sellerFinancingContractAddress;

    address public seaportContractAddress;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting storage.
    uint256[500] private __gap;

    /// @notice The initializer for the marketplace integration contract.
    function initialize(
        address newSellerFinancingContractAddress,
        address newSeaportContractAddress
    ) public initializer {
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
        seaportContractAddress = newSeaportContractAddress;

        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
    }

    function updateSellerFinancingContractAddress(
        address newSellerFinancingContractAddress
    ) external onlyOwner {
        require(
            address(newSellerFinancingContractAddress) != address(0),
            "00055"
        );
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
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

    function buyOnSeaportWithFinancing(
        ISellerFinancing.Offer calldata offer,
        bytes memory signature,
        ISeaport.Order calldata order,
        bytes32 fulfillerConduitKey
    ) external payable nonReentrant {
        _requireIsNotSanctioned(offer.creator);
        _requireIsNotSanctioned(msg.sender);

        _validateOrder(order, offer);

        uint256 considerationAmount = _calculateConsiderationAmount(order);

        // arrange asset amount from borrower side for the purchase
        require(msg.value >= offer.downPaymentAmount, "00047");
        if (msg.value > offer.downPaymentAmount) {
            payable(msg.sender).sendValue(msg.value - offer.downPaymentAmount);
        }

        // this call will fail as this contract should not have a sufficient current balance
        // options:
        // 1. deposit funds into this contract directly
        // 2. have a management contract that has approved WETH, transfer in, execute, or swap to ETH in this function and execute
        // 3. we'll also need a management contract to seizeAssets in default and list NFTs for sale and list with financing

        require(
            ISeaport(seaportContractAddress).fulfillOrder{
                value: considerationAmount
            }(order, fulfillerConduitKey),
            "00048"
        );

        // approve the sellerFinancing contract for the purchased nft
        // validates that order and offer are for same NFT
        IERC721Upgradeable(offer.nftContractAddress).approve(
            sellerFinancingContractAddress,
            offer.nftId
        );

        ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing(
            offer,
            signature,
            msg.sender
        );

        // emit BoughtOnSeaportWithFinancing event
    }

    function _validateOrder(
        ISeaport.Order memory order,
        ISellerFinancing.Offer memory offer
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

    /// @notice This contract needs to accept ETH to acquire enough funds to purchase NFTs
    receive() external payable {}
}
