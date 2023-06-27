//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
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
        address nftContractAddress,
        uint256 nftId
    ) external view returns (Loan memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getLoan(nftContractAddress, nftId, sf);
    }

    /// @inheritdoc ILoanManagement
    function getUnderlyingNft(
        uint256 sellerFinancingTicketId
    ) external view returns (UnderlyingNft memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getUnderlyingNft(sellerFinancingTicketId, sf);
    }

    /// @inheritdoc ILoanManagement
    function calculateMinimumPayment(
        Loan memory loan
    ) public view returns (uint256 minimumPayment, uint256 periodInterest) {
        // if in the current period, else prior to period minimumPayment and interest should remain 0
        if (_currentTimestamp32() >= loan.periodBeginTimestamp) {
            // calculate periods passed
            uint256 numPeriodsPassed = ((_currentTimestamp32() - loan.periodBeginTimestamp) /
                loan.periodDuration) + 1;

            // calculate minimum principal to be paid
            uint256 minimumPrincipalPayment = loan.minimumPrincipalPerPeriod * numPeriodsPassed;

            // if remainingPrincipal is less than minimumPrincipalPayment make minimum payment the remainder of the principal
            if (loan.remainingPrincipal < minimumPrincipalPayment) {
                minimumPrincipalPayment = loan.remainingPrincipal;
            }
            // calculate % interest to be paid to lender
            if (loan.periodInterestRateBps != 0) {
                periodInterest =
                    ((loan.remainingPrincipal * loan.periodInterestRateBps) / NiftyApesStorage.BASE_BPS) *
                    numPeriodsPassed;
            }

            minimumPayment = minimumPrincipalPayment + periodInterest;
        }
    }

    /// @inheritdoc ILoanManagement
    function makePayment(
        address nftContractAddress,
        uint256 nftId
    ) external payable whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        // make payment
        address borrower = _makePayment(nftContractAddress, nftId, msg.value, sf);
        // transfer nft to borrower if loan closed
        if (borrower != address(0)) {
            _transferNft(nftContractAddress, nftId, address(this), borrower);
        }
    }

    /// @inheritdoc ILoanManagement
    function makePaymentBatch(
        address[] memory  nftContractAddresses,
        uint256[] memory nftIds,
        uint256[] memory payments,
        bool partialExecution
    ) external payable whenNotPaused nonReentrant {
        uint256 batchLength = nftContractAddresses.length;
        if (nftIds.length != batchLength) {
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

            address borrower = _makePayment(nftContractAddresses[i], nftIds[i], payments[i], sf);
            // transfer nft to borrower if loan closed
            if (borrower != address(0)) {
                _transferNft(nftContractAddresses[i], nftIds[i], address(this), borrower);
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
        address nftContractAddress,
        uint256 nftId
    ) external whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        _seizeAsset(nftContractAddress, nftId, sf);
    }

    /// @inheritdoc ILoanManagement
    function seizeAssetBatch(
        address[] memory nftContractAddresses,
        uint256[] memory nftIds
    ) external whenNotPaused nonReentrant {
        uint256 batchLength = nftContractAddresses.length;
        if (nftIds.length != batchLength) {
            revert InvalidInputLength();
        }
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        
        for (uint256 i; i < batchLength; ++i) {
            _seizeAsset(nftContractAddresses[i], nftIds[i], sf);
        }
    }

    /// @inheritdoc ILoanManagement
    function instantSell(
        address nftContractAddress,
        uint256 nftId,
        uint256 minProfitAmount,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId, sf);
        // get borrower
        address borrowerAddress = ownerOf(loan.borrowerNftId);

        _requireIsNotSanctioned(msg.sender, sf);
        // requireMsgSenderIsBuyer
        _requireMsgSenderIsValidCaller(borrowerAddress);
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.periodDuration);

        // calculate period interest
        (, uint256 periodInterest) = calculateMinimumPayment(loan);
        // calculate total payment required to close the loan
        uint256 totalPaymentRequired = loan.remainingPrincipal + periodInterest;

        // sell the asset to get sufficient funds to repay loan
        uint256 saleAmountReceived = _sellAsset(
            nftContractAddress,
            nftId,
            totalPaymentRequired + minProfitAmount,
            data,
            sf
        );

        // make payment to close the loan and transfer remainder to the borrower
        _makePayment(nftContractAddress, nftId, saleAmountReceived, sf);

        // emit instant sell event
        emit InstantSell(nftContractAddress, nftId, saleAmountReceived);
    }

    function _makePayment(
        address nftContractAddress,
        uint256 nftId,
        uint256 amountReceived,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (address borrower) {
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId, sf);
        // get borrower
        address borrowerAddress = ownerOf(loan.borrowerNftId);
        // get lender
        address lenderAddress = ownerOf(loan.lenderNftId);

        _requireIsNotSanctioned(borrowerAddress, sf);
        _requireIsNotSanctioned(msg.sender, sf);
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.periodDuration);

        // get minimum payment and period interest values
        (uint256 totalMinimumPayment, uint256 periodInterest) = calculateMinimumPayment(loan);

        // calculate the total possible payment
        uint256 totalPossiblePayment = loan.remainingPrincipal + periodInterest;

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

        uint256 totalRoyaltiesPaid;
        if (loan.payRoyalties) {
            totalRoyaltiesPaid = _payRoyalties(
                nftContractAddress,
                nftId,
                borrowerAddress,
                amountReceived,
                sf
            );
        }

        // payout lender
        _conditionalSendValue(lenderAddress, borrowerAddress, amountReceived - totalRoyaltiesPaid, sf);

        // update loan struct
        loan.remainingPrincipal -= uint128(amountReceived - periodInterest);

        // check if remainingPrincipal is 0
        if (loan.remainingPrincipal == 0) {
            // if principal == 0 set nft transfer address to the borrower
            borrower = borrowerAddress;
            // remove borrower delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                borrowerAddress,
                nftContractAddress,
                nftId,
                false
            );
            // burn borrower nft
            _burn(loan.borrowerNftId);
            // burn lender nft
            _burn(loan.lenderNftId);
            //emit paymentMade event
            emit PaymentMade(
                nftContractAddress,
                nftId,
                amountReceived,
                totalRoyaltiesPaid,
                periodInterest,
                loan
            );
            // emit loan repaid event
            emit LoanRepaid(nftContractAddress, nftId, loan);
            // delete borrower nft id pointer
            delete sf.underlyingNfts[loan.borrowerNftId];
            // delete lender nft id pointer
            delete sf.underlyingNfts[loan.lenderNftId];
            // delete loan
            delete sf.loans[nftContractAddress][nftId];
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
            emit PaymentMade(
                nftContractAddress,
                nftId,
                amountReceived,
                totalRoyaltiesPaid,
                periodInterest,
                loan
            );
        }
    }
    
    function _seizeAsset(
        address nftContractAddress,
        uint256 nftId,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId, sf);
        // get borrower
        address borrowerAddress = ownerOf(loan.borrowerNftId);
        // get lender
        address lenderAddress = ownerOf(loan.lenderNftId);

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
            nftContractAddress,
            nftId,
            false
        );

        // burn borrower nft
        _burn(loan.borrowerNftId);

        // burn lender nft
        _burn(loan.lenderNftId);

        //emit asset seized event
        emit AssetSeized(nftContractAddress, nftId, loan);

        // delete borrower nft id pointer
        delete sf.underlyingNfts[loan.borrowerNftId];
        // delete lender nft id pointer
        delete sf.underlyingNfts[loan.lenderNftId];
        // close loan
        delete sf.loans[nftContractAddress][nftId];

        // transfer NFT from this contract to the lender address
        _transferNft(nftContractAddress, nftId, address(this), lenderAddress);
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
}
