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
import "../interfaces/sellerFinancing/ISellerFinancingErrors.sol";
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
    ISaleExecuter,
    ISellerFinancingErrors
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
        seaportContractAddress = newSeaportContractAddress;
        wethContractAddress = newWethContractAddress;
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
        (ISeaport.Order memory order) = abi.decode(data, (ISeaport.Order));
        _validatePurchaseOrder(order);

        uint256 considerationAmount = _calculateConsiderationAmount(order);

        require(msg.value >= considerationAmount, "Insufficient funds for purchase");
        if (msg.value > considerationAmount) {
            payable(msg.sender).sendValue(msg.value - considerationAmount);
        }
        require(
            ISeaport(seaportContractAddress).fulfillOrder{
                value: considerationAmount
            }(order, bytes32(0)),
            "Seaport fulfill order request failed"
        );

        // approve the sender for the purchased nft
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
        (ISeaport.Order memory order) = abi.decode(data, (ISeaport.Order));
        _validateSaleOrder(order, nftContractAddress, nftId);

        // instantiate weth
        IERC20 asset = IERC20(wethContractAddress);

        // calculate totalConsiderationAmount
        uint256 totalConsiderationAmount;
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            totalConsiderationAmount = order.parameters.consideration[i].endAmount;
        }

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(seaportContractAddress, totalConsiderationAmount);

        // execute sale on Seaport
        if (!ISeaport(seaportContractAddress).fulfillOrder(order, bytes32(0))) {
            revert SeaportOrderNotFulfilled();
        }
        
        // convert weth to eth
        (bool success, ) = wethContractAddress.call(
            abi.encodeWithSignature(
                "withdraw(uint256)",
                order.parameters.offer[0].endAmount - totalConsiderationAmount
            )
        );
        if (!success) {
            revert WethConversionFailed();
        }
        if (order.parameters.offer[0].endAmount - totalConsiderationAmount > 0) {
            // transfer the sale value to caller
            payable(msg.sender).sendValue(order.parameters.offer[0].endAmount - totalConsiderationAmount);
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
        if (order.parameters.consideration[0].itemType != ISeaport.ItemType.ERC721) {
            revert InvalidConsiderationItemType(
                0,
                order.parameters.consideration[0].itemType,
                ISeaport.ItemType.ERC721
            );
        }
        if (order.parameters.consideration[0].token != nftContractAddress) {
            revert InvalidConsiderationToken(
                0,
                order.parameters.consideration[0].token,
                nftContractAddress
            );
        }
        if (order.parameters.consideration[0].identifierOrCriteria != nftId) {
            revert InvalidConsideration0Identifier(
                order.parameters.consideration[0].identifierOrCriteria,
                nftId
            );
        }
        if (order.parameters.offer[0].itemType != ISeaport.ItemType.ERC20) {
            revert InvalidOffer0ItemType(
                order.parameters.offer[0].itemType,
                ISeaport.ItemType.ERC20
            );
        }
        if (order.parameters.offer[0].token != wethContractAddress) {
            revert InvalidOffer0Token(order.parameters.offer[0].token, wethContractAddress);
        }
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            if (order.parameters.consideration[i].itemType != ISeaport.ItemType.ERC20) {
                revert InvalidConsiderationItemType(
                    i,
                    order.parameters.consideration[i].itemType,
                    ISeaport.ItemType.ERC20
                );
            }
            if (order.parameters.consideration[i].token != wethContractAddress) {
                revert InvalidConsiderationToken(
                    i,
                    order.parameters.consideration[i].token,
                    wethContractAddress
                );
            }
        }
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
    
    /// @notice This contract needs to accept ETH from Seaport
    receive() external payable {}
}