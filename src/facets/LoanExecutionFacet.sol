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
contract NiftyApesLoanExecutionFacet is NiftyApesInternal, ILoanExecution {
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @inheritdoc ILoanExecution
    function buyWithSellerFinancing(
        Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 tokenId,
        uint256 tokenAmount
    ) external payable whenNotPaused nonReentrant returns (uint256 loanId) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.SELLER_FINANCING);

        // requireSufficientMsgValue
        _requireSufficientMsgValue(offer, buyer);

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();

        address seller = _commonLoanChecks(offer, signature, buyer, tokenId, tokenAmount, sf);

        // transfer token from seller to this contract, revert on failure
        offer.collateralItem.tokenId = tokenId;
        offer.collateralItem.amount = tokenAmount;
        _transferCollateral(offer.collateralItem, seller, address(this));

        uint256 totalRoyaltiesPaid;
        if (offer.payRoyalties && offer.collateralItem.itemType == ItemType.ERC721) {
            totalRoyaltiesPaid = _payRoyalties(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                buyer,
                offer.loanTerms.itemType,
                offer.loanTerms.token,
                offer.loanTerms.downPaymentAmount,
                sf
            );
        }

        // payout seller
        if (offer.loanTerms.itemType == ItemType.NATIVE) {
            payable(seller).sendValue(offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid);
        } else {
            _transferERC20(
                offer.loanTerms.token,
                buyer,
                seller,
                offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid
            );
        }

        _executeLoan(offer, signature, buyer, seller, sf);

        return sf.loanId - 2;
    }

    /// @inheritdoc ILoanExecution
    function borrow(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 tokenId,
        uint256 tokenAmount
    ) external whenNotPaused nonReentrant returns (uint256 loanId) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.LENDING);
        // loan item must be ERC20
        _requireItemType(offer.loanTerms.itemType, ItemType.ERC20);

        // get storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();

        address lender = _commonLoanChecks(offer, signature, borrower, tokenId, tokenAmount, sf);

        // transfer token from borrower to this contract, revert on failure
        offer.collateralItem.tokenId = tokenId;
        offer.collateralItem.amount = tokenAmount;
        _transferCollateral(offer.collateralItem, borrower, address(this));
        _executeLoan(offer, signature, borrower, lender, sf);

        // payout borrower
        _transferERC20(offer.loanTerms.token, lender, borrower, offer.loanTerms.principalAmount);

        return (sf.loanId - 2);
    }

    /// @inheritdoc ILoanExecution
    function buyWith3rdPartyFinancing(
        Offer memory offer,
        bytes calldata signature,
        address borrower,
        uint256 tokenId,
        uint256 tokenAmount,
        bytes calldata data
    ) external whenNotPaused nonReentrant returns (uint256 loanId) {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.LENDING);

        // get storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();

        // loan item must be ERC20
        _requireItemType(offer.loanTerms.itemType, ItemType.ERC20);

        // revert if collateral not ERC721
        if (
            offer.collateralItem.itemType != ItemType.ERC721 &&
            offer.collateralItem.itemType != ItemType.ERC1155
        ) {
            revert InvalidCollateralItemType();
        }
        address lender = _commonLoanChecks(offer, signature, borrower, tokenId, tokenAmount, sf);

        _executePurchase(offer, borrower, lender, data, sf);

        offer.collateralItem.tokenId = tokenId;
        offer.collateralItem.amount = 0;
        _executeLoan(offer, signature, borrower, lender, sf);

        return sf.loanId - 2;
    }

    function _executePurchase(
        Offer memory offer,
        address borrower,
        address lender,
        bytes calldata data,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private {
        // decode seaport order data
        ISeaport.Order memory order = abi.decode(data, (ISeaport.Order));

        // instantiate weth
        IERC20Upgradeable asset = IERC20Upgradeable(offer.loanTerms.token);

        // calculate totalConsiderationAmount
        uint256 totalConsiderationAmount;
        for (uint256 i = 0; i < order.parameters.totalOriginalConsiderationItems; i++) {
            totalConsiderationAmount += order.parameters.consideration[i].endAmount;
        }

        // transferFrom weth from lender
        asset.safeTransferFrom(lender, address(this), offer.loanTerms.principalAmount);

        // transferFrom downPayment from buyer
        asset.safeTransferFrom(
            borrower,
            address(this),
            totalConsiderationAmount - offer.loanTerms.principalAmount
        );

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(sf.seaportContractAddress, totalConsiderationAmount);

        // execute sale on Seaport
        if (!ISeaport(sf.seaportContractAddress).fulfillOrder(order, bytes32(0))) {
            revert SeaportOrderNotFulfilled();
        }
    }

    /// @inheritdoc ILoanExecution
    function buyNow(
        Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 tokenId,
        uint256 tokenAmount
    ) external payable whenNotPaused nonReentrant {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.SALE);

        // requireSufficientMsgValue
        _requireSufficientMsgValue(offer, buyer);

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();

        address seller = _commonLoanChecks(offer, signature, buyer, tokenId, tokenAmount, sf);

        uint256 totalRoyaltiesPaid;
        if (offer.payRoyalties && offer.collateralItem.itemType == ItemType.ERC721) {
            totalRoyaltiesPaid = _payRoyalties(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                buyer,
                offer.loanTerms.itemType,
                offer.loanTerms.token,
                offer.loanTerms.downPaymentAmount,
                sf
            );
        }

        // payout seller
        if (offer.loanTerms.itemType == ItemType.NATIVE) {
            payable(seller).sendValue(offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid);
        } else {
            _transferERC20(
                offer.loanTerms.token,
                buyer,
                seller,
                offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid
            );
        }

        // transfer token from seller to buyer, revert on failure
        offer.collateralItem.tokenId = tokenId;
        offer.collateralItem.amount = tokenAmount;
        _transferCollateral(offer.collateralItem, seller, buyer);

        emit SaleExecuted(
            offer.collateralItem.token,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            offer.loanTerms.token,
            offer.loanTerms.downPaymentAmount
        );
    }
}
