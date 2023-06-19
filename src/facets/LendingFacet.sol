//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/lending/ILending.sol";
import "../interfaces/seaport/ISeaport.sol";
import "./common/NiftyApesInternal.sol";

/// @title NiftyApes Lending facet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract NiftyApesLendingFacet is
    NiftyApesInternal,
    ILending
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function borrow(
        Offer memory offer,
        bytes calldata signature,
        uint256 nftId
    ) external whenNotPaused nonReentrant returns (uint256 ethReceived) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.LENDING);

        // get storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
        address lender = _commonLoanChecks(offer, signature, msg.sender, nftId, sf);

        // cache this contract eth balance before the weth conversion
        uint256 contractBalanceBefore = address(this).balance;

        // transfer weth from lender
        IERC20Upgradeable(sf.wethContractAddress).safeTransferFrom(
            lender,
            address(this),
            offer.principalAmount
        );

        // convert weth to eth
        (bool success, ) = sf.wethContractAddress.call(
            abi.encodeWithSignature("withdraw(uint256)", offer.principalAmount)
        );
        if (!success) {
            revert WethConversionFailed();
        }

        // calculate ethReceived
        ethReceived = address(this).balance - contractBalanceBefore;

        // transfer nft from msg.sender to this contract, revert on failure
        _transferCollateral(offer.nftContractAddress, nftId, msg.sender, address(this));

        _executeLoan(offer, signature, msg.sender, lender, nftId, sf);

        // payout borrower
        payable(msg.sender).sendValue(ethReceived);
    }

    function buyWith3rdPartyFinancing(
        Offer memory offer,
        bytes calldata signature,
        uint256 nftId,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.LENDING);

        // get storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
        address lender = _commonLoanChecks(offer, signature, msg.sender, nftId, sf);

        // decode seaport order data
        ISeaport.Order memory order = abi.decode(data, (ISeaport.Order));

        // instantiate weth
        IERC20Upgradeable asset = IERC20Upgradeable(sf.wethContractAddress);

        // calculate totalConsiderationAmount
        uint256 totalConsiderationAmount;
        for (uint256 i = 0; i < order.parameters.totalOriginalConsiderationItems; i++) {
            totalConsiderationAmount += order.parameters.consideration[i].endAmount;
        }

        // transferFrom weth from lender
        asset.safeTransferFrom(lender, address(this), offer.principalAmount);

        // transferFrom downPayment from buyer
        asset.safeTransferFrom(
            msg.sender,
            address(this),
            totalConsiderationAmount - offer.principalAmount
        );

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(sf.seaportContractAddress, totalConsiderationAmount);

        // execute sale on Seaport
        if (!ISeaport(sf.seaportContractAddress).fulfillOrder(order, bytes32(0))) {
            revert SeaportOrderNotFulfilled();
        }

        _executeLoan(offer, signature, msg.sender, lender, nftId, sf);
    }
}
