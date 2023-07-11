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
contract NiftyApesLoanManagementFacet is
    NiftyApesInternal,
    ILoanManagement
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @inheritdoc ILoanManagement
    function getLoan(
        uint256 loanId
    ) external view returns (Loan memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getLoan(loanId, sf);
    }

    /// @inheritdoc ILoanManagement
    function getUnderlyingNft(
        uint256 ticketId
    ) external view returns (CollateralItem memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        Loan memory loan = _getLoan(ticketId, sf);
        return loan.collateralItem;
    }

    /// @inheritdoc ILoanManagement
    function calculateMinimumPayment(
        uint256 loanId
    ) public view returns (uint256 minimumPayment, uint256 periodInterest) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        Loan memory loan = _getLoan(loanId, sf);
        return _calculateMinimumPayment(loan, sf);
    }

    function _calculateMinimumPayment(
        Loan memory loan,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private view returns (uint256 minimumPayment, uint256 periodInterest) {
        // if in the current period, else prior to period minimumPayment and interest should remain 0
        if (_currentTimestamp32() >= loan.periodBeginTimestamp) {
            // calculate periods passed
            uint256 numPeriodsPassed = ((_currentTimestamp32() - loan.periodBeginTimestamp) /
                loan.periodDuration) + 1;

            // calculate minimum principal to be paid
            uint256 minimumPrincipalPayment = loan.loanItem.minimumPrincipalPerPeriod * numPeriodsPassed;

            // if remainingPrincipal is less than minimumPrincipalPayment make minimum payment the remainder of the principal
            if (loan.loanItem.principalAmount < minimumPrincipalPayment) {
                minimumPrincipalPayment = loan.loanItem.principalAmount;
            }
            // calculate % interest to be paid to lender
            if (loan.periodInterestRateBps != 0) {
                periodInterest =
                    ((loan.loanItem.principalAmount * loan.periodInterestRateBps) / NiftyApesStorage.BASE_BPS) *
                    numPeriodsPassed;
            }

            minimumPayment = minimumPrincipalPayment + periodInterest;
            minimumPayment += _calculateProtocolFee(minimumPayment, sf);
        }
    }

    function calculateProtocolFee(uint256 loanPaymentAmount) external view returns (uint256) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _calculateProtocolFee(loanPaymentAmount, sf);
    }

    /// @inheritdoc ILoanManagement
    function makePayment(
        uint256 loanId
    ) external payable whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        Loan storage loan = _getLoan(loanId, sf);
        // make payment
        address borrower = _makePayment(loan, msg.value, sf);
        // transfer nft to borrower if loan closed
        if (borrower != address(0)) {
            
            _transferCollateral(loan.collateralItem, address(this), borrower);
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
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
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
                    revert InsufficientMsgValue(
                        msg.value,
                        valueConsumed + payments[i]
                    );
                }
            }
            Loan storage loan = _getLoan(loanIds[i], sf);
            address borrower = _makePayment(loan, payments[i], sf);
            // transfer nft to borrower if loan closed
            if (borrower != address(0)) {
                _transferCollateral(loan.collateralItem, address(this), borrower);
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
    function seizeAsset(
        uint256[] memory loanIds
    ) external whenNotPaused nonReentrant {
        uint256 batchLength = loanIds.length;

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
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
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        // instantiate loan
        Loan storage loan = _getLoan(loanId, sf);
        // get borrower
        address borrowerAddress = ownerOf(loan.loanId);

        _requireIsNotSanctioned(msg.sender, sf);
        // requireMsgSenderIsBuyer
        _requireMsgSenderIsValidCaller(borrowerAddress);
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.periodDuration);

        // calculate period interest
        (, uint256 periodInterest) = _calculateMinimumPayment(loan, sf);
        // calculate total payment required to close the loan
        uint256 totalPaymentRequired = loan.loanItem.principalAmount + periodInterest + _calculateProtocolFee(loan.loanItem.principalAmount + periodInterest, sf);

        // sell the asset to get sufficient funds to repay loan
        uint256 saleAmountReceived = _sellAsset(
            loan.collateralItem.token,
            loan.collateralItem.identifier,
            totalPaymentRequired + minProfitAmount,
            data,
            sf
        );

        // make payment to close the loan and transfer remainder to the borrower
        _makePayment(loan, saleAmountReceived, sf);

        // emit instant sell event
        emit InstantSell(loan.collateralItem.token, loan.collateralItem.identifier, saleAmountReceived);
    }

    function _makePayment(
        Loan storage loan,
        uint256 amountReceived,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (address borrower) {
        // get borrower
        address borrowerAddress = ownerOf(loan.loanId);
        // get lender
        address lenderAddress = ownerOf(loan.loanId + 1);

        _requireIsNotSanctioned(borrowerAddress, sf);
        _requireIsNotSanctioned(msg.sender, sf);
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.periodDuration);

        // get minimum payment and period interest values
        (uint256 totalMinimumPayment, uint256 periodInterest) = _calculateMinimumPayment(loan, sf);

        // calculate the total possible payment
        uint256 totalPossiblePayment = loan.loanItem.principalAmount + periodInterest + _calculateProtocolFee(loan.loanItem.principalAmount + periodInterest, sf);

        //require amountReceived to be larger than the total minimum payment
        if (amountReceived < totalMinimumPayment) {
            revert AmountReceivedLessThanRequiredMinimumPayment(
                amountReceived,
                totalMinimumPayment
            );
        }
        // if amountReceived is greater than the totalPossiblePayment send back the difference
        if (amountReceived > totalPossiblePayment) {
            //send back value
            payable(borrowerAddress).sendValue(amountReceived - totalPossiblePayment);
            // adjust amountReceived value
            amountReceived = totalPossiblePayment;
        }

        // calculate protocol fee
        uint256 protocolFeeAmount = _calculateProtocolFeeShareFromPaymentReceived(amountReceived, sf);
        // send the fee amount to protocol fee recipient
        _sendProtocolFeeToRecipient(protocolFeeAmount, sf);

        uint256 totalRoyaltiesPaid;
        if (loan.payRoyalties) {
            totalRoyaltiesPaid = _payRoyalties(
                loan.collateralItem.token,
                loan.collateralItem.identifier,
                borrowerAddress,
                amountReceived - protocolFeeAmount,
                sf
            );
        }

        // payout lender
        _conditionalSendValue(lenderAddress, borrowerAddress, amountReceived - protocolFeeAmount - totalRoyaltiesPaid, sf);

        // update loan struct
        loan.loanItem.principalAmount -= uint128(amountReceived - protocolFeeAmount - periodInterest);

        // check if remainingPrincipal is 0
        if (loan.loanItem.principalAmount == 0) {
            // if principal == 0 set nft transfer address to the borrower
            borrower = borrowerAddress;
            // remove borrower delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                borrowerAddress,
                loan.collateralItem.token,
                loan.collateralItem.identifier,
                false
            );
            // burn borrower nft
            _burn(loan.loanId);
            // burn lender nft
            _burn(loan.loanId + 1);
            //emit paymentMade event
            // emit PaymentMade(
            //     loan.collateralItem.token,
            //     loan.collateralItem.identifier,
            //     amountReceived,
            //     protocolFeeAmount,
            //     totalRoyaltiesPaid,
            //     periodInterest,
            //     loan
            // );
            // // emit loan repaid event
            // emit LoanRepaid(loan.collateralItem.token, loan.collateralItem.identifier, loan);
            // // delete loan
            // delete sf.loans[loan.loanId];
        }
        //else emit paymentMade event and update loan
        else {
            // if in the current period, else prior to period begin and end should remain the same
            if (_currentTimestamp32() >= loan.periodBeginTimestamp) {
                uint256 numPeriodsPassed = ((_currentTimestamp32() - loan.periodBeginTimestamp) /
                    loan.periodDuration) + 1;
                // increment the currentPeriodBegin and End Timestamps equal to the periodDuration times numPeriodsPassed
                loan.periodBeginTimestamp += loan.periodDuration * uint32(numPeriodsPassed);
                loan.periodEndTimestamp += loan.periodDuration * uint32(numPeriodsPassed);
            }

            //emit paymentMade event
            // emit PaymentMade(
            //     loan.collateralItem.token,
            //     loan.collateralItem.identifier,
            //     amountReceived,
            //     protocolFeeAmount,
            //     totalRoyaltiesPaid,
            //     periodInterest,
            //     loan
            // );
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
        IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
            borrowerAddress,
            loan.collateralItem.token,
            loan.collateralItem.identifier,
            false
        );

        // burn borrower nft
        _burn(loan.loanId);

        // burn lender nft
        _burn(loan.loanId + 1);

        //emit asset seized event
        emit AssetSeized(loan.collateralItem.token, loan.collateralItem.identifier, loan);

        // close loan
        delete sf.loans[loan.loanId];

        // transfer NFT from this contract to the lender address
        _transferCollateral(loan.collateralItem, address(this), lenderAddress);
    }

    function _sellAsset(
        address nftContractAddress,
        uint256 nftId,
        uint256 minSaleAmount,
        bytes calldata data,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private returns (uint256 saleAmountReceived) {
        // approve the NFT for Seaport conduit
        IERC721Upgradeable(nftContractAddress).approve(sf.seaportContractAddress, nftId);

        // decode seaport order data
        ISeaport.Order memory order = abi.decode(data, (ISeaport.Order));

        // validate order
        _validateSaleOrder(order, nftContractAddress, nftId, sf);

        // instantiate weth
        IERC20Upgradeable asset = IERC20Upgradeable(sf.wethContractAddress);

        // calculate totalConsiderationAmount
        uint256 totalConsiderationAmount;
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            totalConsiderationAmount += order.parameters.consideration[i].endAmount;
        }

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(sf.seaportContractAddress, totalConsiderationAmount);

        // cache this contract eth balance before the sale
        uint256 contractBalanceBefore = address(this).balance;

        // execute sale on Seaport
        if (!ISeaport(sf.seaportContractAddress).fulfillOrder(order, bytes32(0))) {
            revert SeaportOrderNotFulfilled();
        }

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

        // check amount received is more than minSaleAmount
        if (saleAmountReceived < minSaleAmount) {
            revert InsufficientAmountReceivedFromSale(saleAmountReceived, minSaleAmount);
        }
    }

    function _validateSaleOrder(
        ISeaport.Order memory order,
        address nftContractAddress,
        uint256 nftId,
        NiftyApesStorage.SellerFinancingStorage storage sf
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
        if (order.parameters.offer[0].token != sf.wethContractAddress) {
            revert InvalidOffer0Token(order.parameters.offer[0].token, sf.wethContractAddress);
        }
        if (order.parameters.offer.length != 1) {
            revert InvalidOfferLength(order.parameters.offer.length, 1);
        }
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            if (order.parameters.consideration[i].itemType != ISeaport.ItemType.ERC20) {
                revert InvalidConsiderationItemType(
                    i,
                    order.parameters.consideration[i].itemType,
                    ISeaport.ItemType.ERC20
                );
            }
            if (order.parameters.consideration[i].token != sf.wethContractAddress) {
                revert InvalidConsiderationToken(
                    i,
                    order.parameters.consideration[i].token,
                    sf.wethContractAddress
                );
            }
        }
    }

    function _calculateProtocolFee(uint256 loanPaymentAmount, NiftyApesStorage.SellerFinancingStorage storage sf) private view returns (uint256) {
        return (loanPaymentAmount * sf.protocolFeeBPS) / NiftyApesStorage.BASE_BPS;
    }

    function _calculateProtocolFeeShareFromPaymentReceived(uint256 paymentReceived, NiftyApesStorage.SellerFinancingStorage storage sf) private view returns (uint256) {
        uint256 loanPaymentAmount = ((paymentReceived*NiftyApesStorage.BASE_BPS)+NiftyApesStorage.BASE_BPS + sf.protocolFeeBPS - 1)/(NiftyApesStorage.BASE_BPS + sf.protocolFeeBPS);
        return paymentReceived - loanPaymentAmount;
    }

    function _sendProtocolFeeToRecipient(uint256 amount, NiftyApesStorage.SellerFinancingStorage storage sf) private {
        if (sf.protocolFeeRecipient != address(0)) {
            sf.protocolFeeRecipient.sendValue(amount);
        }
    }
}
