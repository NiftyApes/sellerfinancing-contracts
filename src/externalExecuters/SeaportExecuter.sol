//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/security/Pausable.sol";
import "@openzeppelin-norm/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin-norm/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin-norm/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin-norm/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-norm/contracts/token/ERC20/IERC20.sol";
import "../interfaces/seaport/ISeaport.sol";
import "../interfaces/sanctions/SanctionsList.sol";
import "./interfaces/IPurchaseExecuter.sol";
import "./interfaces/ISaleExecuter.sol";

/// @notice Integration of Seaport to seller financing to allow purchase and sale of NFTs with financing
/// @title SeaportExecuter
/// @custom:version 1.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract SeaportExecuter is
    Ownable,
    ReentrancyGuard,
    ERC721Holder,
    Pausable,
    IPurchaseExecuter,
    ISaleExecuter
{
    using Address for address payable;
    using SafeERC20 for IERC20;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    address public seaportContractAddress;

    address public wethContractAddress;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    constructor (
        address newSeaportContractAddress,
        address newWethContractAddress
    ) public {
        
    }

    function updateSeaportContractAddress(address newSeaportContractAddress)
        external
        onlyOwner
    {
        require(address(newSeaportContractAddress) != address(0), "00035");
        seaportContractAddress = newSeaportContractAddress;
    }
    
    function updateWethContractAddress(address newWethContractAddress)
        external onlyOwner
    {
        require(address(newWethContractAddress) != address(0), "00035");
        wethContractAddress = newWethContractAddress;
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

    function executePurchase(
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external payable override nonReentrant whenNotPaused returns (bool) {
        _requireIsNotSanctioned(msg.sender);
        // decode data
        (ISeaport.Order memory order, bytes32 fulfillerConduitKey) = abi.decode(data, (ISeaport.Order, bytes32));
        _validatePurchaseOrder(order);

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
        IERC721(nftContractAddress).approve(
            msg.sender,
            nftId
        );
        return true;
    }

    function executeSale(
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external override nonReentrant whenNotPaused returns (bool) {
        // approve the NFT for Seaport conduit
        IERC721(nftContractAddress).approve(seaportContractAddress, nftId);

        // decode data
        (ISeaport.Order memory order, bytes32 fulfillerConduitKey) = abi.decode(data, (ISeaport.Order, bytes32));
        _validateSaleOrder(order, nftContractAddress, nftId);

        IERC20 asset = IERC20(wethContractAddress);

        uint256 allowance = asset.allowance(address(this), seaportContractAddress);
        if (allowance > 0) {
            asset.safeDecreaseAllowance(seaportContractAddress, allowance);
        }
        asset.safeIncreaseAllowance(seaportContractAddress, order.parameters.consideration[1].endAmount);

        uint256 contractBalanceBefore = address(this).balance;

        require(
            ISeaport(seaportContractAddress).fulfillOrder(order, fulfillerConduitKey),
            "00048"
        );
        
        // convert weth to eth
        (bool success,) = wethContractAddress.call(abi.encodeWithSignature("withdraw(uint256)", order.parameters.offer[0].endAmount - order.parameters.consideration[1].endAmount));
        require(success, "00068");

        uint256 contractBalanceAfter = address(this).balance;

        if (contractBalanceAfter - contractBalanceBefore > 0) {
            // transfer the asset to FlashSell to allow settling the loan
            payable(msg.sender).sendValue(contractBalanceAfter - contractBalanceBefore);
        }
        return true;
    }

    function _validatePurchaseOrder(
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

    function _validateSaleOrder(
        ISeaport.Order memory order,
        address nftContractAddress,
        uint256 nftId
    ) internal view {
        require(order.parameters.consideration[0].itemType == ISeaport.ItemType.ERC721, "00067");
        require(order.parameters.consideration[0].token == nftContractAddress, "00067");
        require(order.parameters.consideration[0].identifierOrCriteria == nftId, "00067");
        require(order.parameters.offer[0].itemType == ISeaport.ItemType.ERC20, "00067");
        require(order.parameters.consideration[1].itemType == ISeaport.ItemType.ERC20, "00067");
        require(order.parameters.offer[0].token == wethContractAddress,  "00067");
        require(order.parameters.consideration[1].token == wethContractAddress,  "00067");
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
