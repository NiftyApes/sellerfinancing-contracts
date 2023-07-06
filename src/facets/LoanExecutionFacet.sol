//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/loanExecution/ILoanExecution.sol";
import "../interfaces/seaport/ISeaport.sol";
import "./common/NiftyApesInternal.sol";

/// @title NiftyApes LoanExecution facet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract NiftyApesLoanExecutionFacet is
    NiftyApesInternal,
    ILoanExecution
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @inheritdoc ILoanExecution
    function buyWithSellerFinancing(
        Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 nftId
    ) external payable whenNotPaused nonReentrant returns (uint256 loanId) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.SELLER_FINANCING);
        // requireSufficientMsgValue
        if (msg.value < offer.loanItem.downPaymentAmount) {
            revert InsufficientMsgValue(msg.value, offer.loanItem.downPaymentAmount);
        }
        // if msg.value is too high, return excess value
        if (msg.value > offer.loanItem.downPaymentAmount) {
            payable(buyer).sendValue(msg.value - offer.loanItem.downPaymentAmount);
        }

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
        address seller = _commonLoanChecks(offer, signature, buyer, nftId, sf);

        // transfer nft from seller to this contract, revert on failure
        offer.collateralItem.identifier = nftId;
        _transferCollateral(offer.collateralItem, seller, address(this));

        uint256 totalRoyaltiesPaid;
        if (offer.payRoyalties) {
            totalRoyaltiesPaid = _payRoyalties(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                buyer,
                offer.loanItem.downPaymentAmount,
                sf
            );
        }
        
        // payout seller
        payable(seller).sendValue(offer.loanItem.downPaymentAmount - totalRoyaltiesPaid);

        _executeLoan(offer, signature, buyer, seller, nftId, sf);

        return sf.loanId - 2;
    }

    /// @inheritdoc ILoanExecution
    function borrow(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId
    ) external whenNotPaused nonReentrant returns (uint256 loanId, uint256 ethReceived) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.LENDING);

        // get storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
        address lender = _commonLoanChecks(offer, signature, borrower, nftId, sf);

        // cache this contract eth balance before the weth conversion
        uint256 contractBalanceBefore = address(this).balance;

        // transfer weth from lender
        IERC20Upgradeable(sf.wethContractAddress).safeTransferFrom(
            lender,
            address(this),
            offer.loanItem.principalAmount
        );

        // convert weth to eth
        (bool success, ) = sf.wethContractAddress.call(
            abi.encodeWithSignature("withdraw(uint256)", offer.loanItem.principalAmount)
        );
        if (!success) {
            revert WethConversionFailed();
        }

        // calculate ethReceived
        ethReceived = address(this).balance - contractBalanceBefore;

        // transfer nft from borrower to this contract, revert on failure
        IERC721Upgradeable(offer.collateralItem.token).safeTransferFrom(borrower, address(this), nftId);

        _executeLoan(offer, signature, borrower, lender, nftId, sf);

        // payout borrower
        payable(borrower).sendValue(ethReceived);

        return (sf.loanId - 2, ethReceived);
    }

    /// @inheritdoc ILoanExecution
    function buyWith3rdPartyFinancing(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 nftId,
        bytes calldata data
    ) external whenNotPaused nonReentrant returns (uint256 loanId) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.LENDING);

        // get storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
        address lender = _commonLoanChecks(offer, signature, borrower, nftId, sf);

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
        asset.safeTransferFrom(lender, address(this), offer.loanItem.principalAmount);

        // transferFrom downPayment from buyer
        asset.safeTransferFrom(
            borrower,
            address(this),
            totalConsiderationAmount - offer.loanItem.principalAmount
        );

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(sf.seaportContractAddress, totalConsiderationAmount);

        // execute sale on Seaport
        if (!ISeaport(sf.seaportContractAddress).fulfillOrder(order, bytes32(0))) {
            revert SeaportOrderNotFulfilled();
        }

        _executeLoan(offer, signature, borrower, lender, nftId, sf);

        return sf.loanId - 2;
    }
}
