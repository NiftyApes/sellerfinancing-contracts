//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/loanManagement/ILoanManagement.sol";
import "../interfaces/seaport/ISeaport.sol";
import "./common/NiftyApesInternal.sol";

/// @title NiftyApes LoanManagement facet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract NiftyApesLoanManagementFacet is NiftyApesInternal, ILoanManagement {
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @inheritdoc ILoanManagement
    function getLoan(uint256 loanId) external view returns (Loan memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();
        return _getLoan(loanId, sf);
    }

    /// @inheritdoc ILoanManagement
    function getUnderlyingNft(uint256 ticketId) external view returns (CollateralItem memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();
        Loan memory loan = _getLoan(ticketId, sf);
        return loan.collateralItem;
    }

    /// @inheritdoc ILoanManagement
    function calculateMinimumPayment(
        uint256 loanId
    )
        public
        view
        returns (uint256 minimumPayment, uint256 periodInterest, uint256 protocolFeeAmount)
    {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();
        Loan memory loan = _getLoan(loanId, sf);
        return _calculateMinimumPayment(loan, sf);
    }

    function _calculateMinimumPayment(
        Loan memory loan,
        NiftyApesStorage.SellerFinancingStorage storage sf
    )
        private
        view
        returns (uint256 minimumPayment, uint256 periodInterest, uint256 protocolFeeAmount)
    {
        // if in the current period, else prior to period minimumPayment and interest should remain 0
        if (_currentTimestamp32() >= loan.periodBeginTimestamp) {
            // calculate periods passed
            uint256 numPeriodsPassed = ((_currentTimestamp32() - loan.periodBeginTimestamp) /
                loan.loanTerms.periodDuration) + 1;

            // calculate minimum principal to be paid
            uint256 minimumPrincipalPayment = loan.loanTerms.minimumPrincipalPerPeriod *
                numPeriodsPassed;

            // if remainingPrincipal is less than minimumPrincipalPayment make minimum payment the remainder of the principal
            if (loan.loanTerms.principalAmount < minimumPrincipalPayment) {
                minimumPrincipalPayment = loan.loanTerms.principalAmount;
            }
            // calculate % interest to be paid to lender
            if (loan.loanTerms.periodInterestRateBps != 0) {
                periodInterest =
                    ((loan.loanTerms.principalAmount * loan.loanTerms.periodInterestRateBps) /
                        NiftyApesStorage.BASE_BPS) *
                    numPeriodsPassed;
            }
            // calculate fee to be paid to protocolFeeRecpient
            if (loan.loanTerms.periodInterestRateBps != 0) {
                protocolFeeAmount =
                    _calculateProtocolFee(loan.loanTerms.principalAmount, sf) *
                    numPeriodsPassed;
            }
            minimumPayment = minimumPrincipalPayment + periodInterest + protocolFeeAmount;
        }
    }

    /// @inheritdoc ILoanManagement
    function makePayment(
        uint256 loanId,
        uint256 paymentAmount
    ) external payable whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();
        Loan storage loan = _getLoan(loanId, sf);
        if (loan.loanTerms.itemType == ItemType.NATIVE && msg.value != paymentAmount) {
            revert ValueReceivedNotEqualToPaymentAmount();
        }
        CollateralItem memory collateralItem = loan.collateralItem;
        // make payment
        address borrower = _makePayment(loan, paymentAmount, msg.sender, sf);
        // transfer token to borrower if loan closed
        if (borrower != address(0)) {
            _transferCollateral(collateralItem, address(this), borrower);
        }
    }

    /// @inheritdoc ILoanManagement
    function makePaymentBatch(
        uint256[] memory loanIds,
        uint256[] memory payments,
        bool partialExecution
    ) external payable whenNotPaused nonReentrant {
        uint256 batchLength = loanIds.length;
        if (payments.length != batchLength) {
            revert InvalidInputLength();
        }

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();

        uint256 valueConsumed;

        // loop through the list to execute payment
        for (uint256 i; i < batchLength; ++i) {
            // if remaining value is not sufficient to execute ith payment
            if (msg.value - valueConsumed < payments[i]) {
                // if partial execution is allowed then move to next offer
                if (partialExecution) {
                    continue;
                }
                // else revert
                else {
                    revert InsufficientMsgValue(msg.value, valueConsumed + payments[i]);
                }
            }
            Loan storage loan = _getLoan(loanIds[i], sf);
            CollateralItem memory collateralItem = loan.collateralItem;
            address borrower = _makePayment(loan, payments[i], msg.sender, sf);
            // transfer token to borrower if loan closed
            if (borrower != address(0)) {
                _transferCollateral(collateralItem, address(this), borrower);
            }
            // add current payment to the `valueConsumed`
            valueConsumed += payments[i];
        }
        // send any unused value back to msg.sender
        if (msg.value - valueConsumed > 0) {
            payable(msg.sender).sendValue(msg.value - valueConsumed);
        }
    }

    /// @inheritdoc ILoanManagement
    function seizeAsset(uint256[] memory loanIds) external whenNotPaused nonReentrant {
        uint256 batchLength = loanIds.length;

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();

        for (uint256 i; i < batchLength; ++i) {
            _seizeAsset(loanIds[i], sf);
        }
    }

    /// @inheritdoc ILoanManagement
    function instantSell(
        uint256 loanId,
        uint256 minProfitAmount,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage
            .sellerFinancingStorage();
        // instantiate loan
        Loan storage loan = _getLoan(loanId, sf);
        // get borrower
        address borrowerAddress = ownerOf(loan.loanId);

        if (
            loan.collateralItem.itemType != ItemType.ERC721 &&
            loan.collateralItem.itemType != ItemType.ERC1155
        ) {
            revert InvalidCollateralItemType();
        }
        _requireIsNotSanctioned(msg.sender, sf);
        // requireMsgSenderIsBuyer
        if (msg.sender != address(this)) {
            _requireMsgSenderIsValidCaller(borrowerAddress);
        }
        
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.loanTerms.periodDuration);

        // calculate period interest
        (, uint256 periodInterest, uint256 protocolFeeAmount) = _calculateMinimumPayment(loan, sf);
        // calculate total payment required to close the loan
        uint256 totalPaymentRequired = loan.loanTerms.principalAmount +
            periodInterest +
            protocolFeeAmount;

        // sell the asset to get sufficient funds to repay loan
        uint256 saleAmountReceived = _sellAsset(
            loan,
            totalPaymentRequired + minProfitAmount,
            data,
            sf
        );
        // emit instant sell event
        emit InstantSell(
            loan.collateralItem.token,
            loan.collateralItem.tokenId,
            saleAmountReceived
        );

        // approve ourselves to avoid revert in erc20 transfers
        if (loan.loanTerms.itemType == ItemType.ERC20) {
            IERC20Upgradeable(loan.loanTerms.token).approve(address(this), saleAmountReceived);
        }

        // make payment to close the loan
        _makePayment(loan, saleAmountReceived, address(this), sf);
    }

    function _makePayment(
        Loan storage loan,
        uint256 paymentAmount,
        address fromAddress,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (address borrowerAddress) {
        // get borrower
        borrowerAddress = ownerOf(loan.loanId);

        _requireIsNotSanctioned(borrowerAddress, sf);
        _requireIsNotSanctioned(msg.sender, sf);
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.loanTerms.periodDuration);

        // get minimum payment, period interest and period protocol fee values
        (
            uint256 totalMinimumPayment,
            uint256 periodInterest,
            uint256 protocolFeeAmount
        ) = _calculateMinimumPayment(loan, sf);

        // calculate the total possible payment
        uint256 totalPossiblePayment = loan.loanTerms.principalAmount +
            periodInterest +
            protocolFeeAmount;

        //require paymentAmount to be larger than the total minimum payment
        if (paymentAmount < totalMinimumPayment) {
            revert PaymentReceivedLessThanRequiredMinimumPayment(
                paymentAmount,
                totalMinimumPayment
            );
        }
        // if paymentAmount is greater than the totalPossiblePayment send back the difference
        if (paymentAmount > totalPossiblePayment) {
            // send back value if loanItem NATIVE ETH
            if (loan.loanTerms.itemType == ItemType.NATIVE) {
                payable(borrowerAddress).sendValue(paymentAmount - totalPossiblePayment);
            }
            if (fromAddress == address(this) && loan.loanTerms.itemType == ItemType.ERC20) {
                _transferERC20(
                    loan.loanTerms.token,
                    address(this),
                    borrowerAddress,
                    paymentAmount - totalPossiblePayment
                );
            }

            // adjust paymentAmount value
            paymentAmount = totalPossiblePayment;
        }

        // send the fee amount to protocol fee recipient
        if (sf.protocolFeeRecipient != address(0) && protocolFeeAmount > 0) {
            if (loan.loanTerms.itemType == ItemType.NATIVE) {
                sf.protocolFeeRecipient.sendValue(protocolFeeAmount);
            } else {
                _transferERC20(
                    loan.loanTerms.token,
                    fromAddress,
                    sf.protocolFeeRecipient,
                    protocolFeeAmount
                );
            }
        }

        uint256 totalRoyaltiesPaid;
        if (loan.payRoyalties && loan.collateralItem.itemType == ItemType.ERC721) {
            if (loan.loanTerms.itemType == ItemType.NATIVE) {
                totalRoyaltiesPaid = _payRoyalties(
                    loan.collateralItem.token,
                    loan.collateralItem.tokenId,
                    borrowerAddress,
                    loan.loanTerms.itemType,
                    loan.loanTerms.token,
                    paymentAmount - protocolFeeAmount,
                    sf
                );
            } else {
                totalRoyaltiesPaid = _payRoyalties(
                    loan.collateralItem.token,
                    loan.collateralItem.tokenId,
                    fromAddress,
                    loan.loanTerms.itemType,
                    loan.loanTerms.token,
                    paymentAmount - protocolFeeAmount,
                    sf
                );
            }
        }

        // payout lender
        if (loan.loanTerms.itemType == ItemType.NATIVE) {
            _conditionalSendValue(
                ownerOf(loan.loanId + 1),
                borrowerAddress,
                paymentAmount - protocolFeeAmount - totalRoyaltiesPaid,
                sf
            );
        } else {
            _transferERC20(
                loan.loanTerms.token,
                fromAddress,
                ownerOf(loan.loanId + 1),
                paymentAmount - protocolFeeAmount - totalRoyaltiesPaid
            );
        }

        // update loan struct
        loan.loanTerms.principalAmount -= uint128(
            paymentAmount - protocolFeeAmount - periodInterest
        );

        return
            _updateLoan(
                loan,
                paymentAmount,
                protocolFeeAmount,
                totalRoyaltiesPaid,
                periodInterest,
                borrowerAddress,
                sf
            );
    }

    function _updateLoan(
        Loan storage loan,
        uint256 paymentAmount,
        uint256 protocolFeeAmount,
        uint256 totalRoyaltiesPaid,
        uint256 periodInterest,
        address borrowerAddress,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private returns (address) {
        // check if remainingPrincipal is 0
        if (loan.loanTerms.principalAmount == 0) {
            // remove borrower delegate.cash delegation if collateral ERC721
            if (loan.collateralItem.itemType == ItemType.ERC721) {
                IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                    borrowerAddress,
                    loan.collateralItem.token,
                    loan.collateralItem.tokenId,
                    false
                );
            }

            // burn borrower token
            _burn(loan.loanId);
            // burn lender token
            _burn(loan.loanId + 1);
            //emit paymentMade event
            emit PaymentMade(
                loan.collateralItem.token,
                loan.collateralItem.tokenId,
                paymentAmount,
                protocolFeeAmount,
                totalRoyaltiesPaid,
                periodInterest,
                loan
            );
            // emit loan repaid event
            emit LoanRepaid(loan.collateralItem.token, loan.collateralItem.tokenId, loan);
            // delete loan
            delete sf.loans[loan.loanId];
            // return borrowerAddress
            return borrowerAddress;
        }
        //else emit paymentMade event and update loan
        else {
            // if in the current period, else prior to period begin and end should remain the same
            if (_currentTimestamp32() >= loan.periodBeginTimestamp) {
                uint256 numPeriodsPassed = ((_currentTimestamp32() - loan.periodBeginTimestamp) /
                    loan.loanTerms.periodDuration) + 1;
                // increment the currentPeriodBegin and End Timestamps equal to the periodDuration times numPeriodsPassed
                loan.periodBeginTimestamp +=
                    loan.loanTerms.periodDuration *
                    uint32(numPeriodsPassed);
                loan.periodEndTimestamp += loan.loanTerms.periodDuration * uint32(numPeriodsPassed);
            }

            //emit paymentMade event
            emit PaymentMade(
                loan.collateralItem.token,
                loan.collateralItem.tokenId,
                paymentAmount,
                protocolFeeAmount,
                totalRoyaltiesPaid,
                periodInterest,
                loan
            );
            // return borrowerAddress as zero
            return address(0);
        }
    }

    function _seizeAsset(
        uint256 loanId,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        // instantiate loan
        Loan storage loan = _getLoan(loanId, sf);
        // get borrower
        address borrowerAddress = ownerOf(loan.loanId);
        // get lender
        address lenderAddress = ownerOf(loan.loanId + 1);

        _requireIsNotSanctioned(lenderAddress, sf);
        // requireMsgSenderIsSeller
        _requireMsgSenderIsValidCaller(lenderAddress);
        // requireLoanInDefault
        if (_currentTimestamp32() < loan.periodEndTimestamp) {
            revert LoanNotInDefault();
        }

        // remove borrower delegate.cash delegation
        if (loan.collateralItem.itemType == ItemType.ERC721) {
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                borrowerAddress,
                loan.collateralItem.token,
                loan.collateralItem.tokenId,
                false
            );
        }

        // burn borrower token
        _burn(loan.loanId);

        // burn lender token
        _burn(loan.loanId + 1);

        //emit asset seized event
        emit AssetSeized(loan.collateralItem.token, loan.collateralItem.tokenId, loan);

        // transfer NFT from this contract to the lender address
        _transferCollateral(loan.collateralItem, address(this), lenderAddress);

        // close loan
        delete sf.loans[loan.loanId];
    }

    function _sellAsset(
        Loan memory loan,
        uint256 minSaleAmount,
        bytes calldata data,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private returns (uint256 saleAmountReceived) {
        // approve the collateral for Seaport conduit
        if (loan.collateralItem.itemType == ItemType.ERC1155) {
            IERC1155Upgradeable(loan.collateralItem.token).setApprovalForAll(
                sf.seaportContractAddress,
                true
            );
        } else {
            IERC721Upgradeable(loan.collateralItem.token).approve(
                sf.seaportContractAddress,
                loan.collateralItem.tokenId
            );
        }

        // decode seaport order data
        ISeaport.Order memory order = abi.decode(data, (ISeaport.Order));

        // validate order
        _validateSaleOrder(order, loan, sf);
        // instantiate loan token
        IERC20Upgradeable asset;
        if (loan.loanTerms.itemType == ItemType.NATIVE) {
            asset = IERC20Upgradeable(sf.wethContractAddress);
        } else {
            asset = IERC20Upgradeable(loan.loanTerms.token);
        }

        // calculate totalConsiderationAmount
        uint256 totalConsiderationAmount;
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            totalConsiderationAmount += order.parameters.consideration[i].endAmount;
        }

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(sf.seaportContractAddress, totalConsiderationAmount);

        // cache this contract eth balance before the sale
        uint256 contractBalanceBefore;
        if (loan.loanTerms.itemType == ItemType.NATIVE) {
            contractBalanceBefore = address(this).balance;
        } else {
            contractBalanceBefore = asset.balanceOf(address(this));
        }

        // execute sale on Seaport
        if (!ISeaport(sf.seaportContractAddress).fulfillOrder(order, bytes32(0))) {
            revert SeaportOrderNotFulfilled();
        }

        // set the seaport approval to false if erc1155
        if (loan.collateralItem.itemType == ItemType.ERC1155) {
            IERC1155Upgradeable(loan.collateralItem.token).setApprovalForAll(
                sf.seaportContractAddress,
                false
            );
        }

        if (loan.loanTerms.itemType == ItemType.NATIVE) {
            // convert weth to eth
            (bool success, ) = sf.wethContractAddress.call(
                abi.encodeWithSignature(
                    "withdraw(uint256)",
                    order.parameters.offer[0].endAmount - totalConsiderationAmount
                )
            );
            if (!success) {
                revert WethConversionFailed();
            }
            // calculate saleAmountReceived
            saleAmountReceived = address(this).balance - contractBalanceBefore;
        } else {
            // calculate saleAmountReceived
            saleAmountReceived = asset.balanceOf(address(this)) - contractBalanceBefore;
        }

        // check amount received is more than minSaleAmount else revert
        if (saleAmountReceived < minSaleAmount) {
            revert InsufficientAmountReceivedFromSale(saleAmountReceived, minSaleAmount);
        }
    }

    function _validateSaleOrder(
        ISeaport.Order memory order,
        Loan memory loan,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal view {
        if (
            uint(order.parameters.consideration[0].itemType) != uint(loan.collateralItem.itemType)
        ) {
            revert InvalidConsiderationItemType(0, order.parameters.consideration[0].itemType);
        }
        if (order.parameters.consideration[0].token != loan.collateralItem.token) {
            revert InvalidConsiderationToken(
                0,
                order.parameters.consideration[0].token,
                loan.collateralItem.token
            );
        }
        if (order.parameters.consideration[0].identifierOrCriteria != loan.collateralItem.tokenId) {
            revert InvalidConsideration0Identifier(
                order.parameters.consideration[0].identifierOrCriteria,
                loan.collateralItem.tokenId
            );
        }
        if (order.parameters.offer[0].itemType != ISeaport.ItemType.ERC20) {
            revert InvalidOffer0ItemType(
                order.parameters.offer[0].itemType,
                ISeaport.ItemType.ERC20
            );
        }
        if (
            loan.loanTerms.itemType == ItemType.NATIVE &&
            order.parameters.offer[0].token != sf.wethContractAddress
        ) {
            revert InvalidOffer0Token(order.parameters.offer[0].token, sf.wethContractAddress);
        }
        if (
            loan.loanTerms.itemType == ItemType.ERC20 &&
            order.parameters.offer[0].token != loan.loanTerms.token
        ) {
            revert InvalidOffer0Token(order.parameters.offer[0].token, loan.loanTerms.token);
        }
        if (order.parameters.offer.length != 1) {
            revert InvalidOfferLength(order.parameters.offer.length, 1);
        }
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            if (order.parameters.consideration[i].itemType != ISeaport.ItemType.ERC20) {
                revert InvalidConsiderationItemType(i, order.parameters.consideration[i].itemType);
            }
            if (
                loan.loanTerms.itemType == ItemType.NATIVE &&
                order.parameters.consideration[i].token != sf.wethContractAddress
            ) {
                revert InvalidConsiderationToken(
                    i,
                    order.parameters.consideration[i].token,
                    sf.wethContractAddress
                );
            }
            if (
                loan.loanTerms.itemType == ItemType.ERC20 &&
                order.parameters.consideration[i].token != loan.loanTerms.token
            ) {
                revert InvalidConsiderationToken(
                    i,
                    order.parameters.consideration[i].token,
                    loan.loanTerms.token
                );
            }
        }
    }

    function _calculateProtocolFee(
        uint256 loanPaymentAmount,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private view returns (uint256) {
        return (loanPaymentAmount * sf.protocolFeeBPS) / NiftyApesStorage.BASE_BPS;
    }
}
