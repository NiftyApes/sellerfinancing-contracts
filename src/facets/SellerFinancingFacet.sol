//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/sellerFinancing/ISellerFinancing.sol";
import "../interfaces/sanctions/SanctionsList.sol";
import "../interfaces/royaltyRegistry/IRoyaltyEngineV1.sol";
import "../interfaces/delegateCash/IDelegationRegistry.sol";
import "../interfaces/seaport/ISeaport.sol";
import "../lib/ECDSABridge.sol";
import "./common/NiftyApesInternal.sol";
import { LibDiamond } from "../diamond/libraries/LibDiamond.sol";

/// @title NiftyApes Seller Financing facet
/// @custom:version 2.0
/// @author captnseagraves (captnseagraves.eth)
/// @custom:contributor zishansami102 (zishansami.eth)
/// @custom:contributor zjmiller (zjmiller.eth)
contract NiftyApesSellerFinancingFacet is
    NiftyApesInternal,
    ISellerFinancing
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice The initializer for the NiftyApes protocol.
    ///         NiftyApes is intended to be deployed as one of the facets to a diamond and thus needs to initialize
    ///         its state outside of a constructor.
    function initialize(
        address newRoyaltiesEngineContractAddress,
        address newDelegateRegistryContractAddress,
        address newSeaportContractAddress,
        address newWethContractAddress
    ) public initializer {
        _requireNonZeroAddress(newRoyaltiesEngineContractAddress);
        _requireNonZeroAddress(newDelegateRegistryContractAddress);
        _requireNonZeroAddress(newSeaportContractAddress);
        _requireNonZeroAddress(newWethContractAddress);

        EIP712Upgradeable.__EIP712_init("NiftyApes_SellerFinancing", "0.0.1");
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
        ERC721Upgradeable.__ERC721_init("NiftyApes Seller Financing Tickets", "BANANAS");
        ERC721URIStorageUpgradeable.__ERC721URIStorage_init();

        // manually setting interfaceIds to be true,
        // since we have an independent supportsInterface in diamondLoupe facet
        // and has a separate mapping storage to mark the supported interfaces as true
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC721Upgradeable).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721MetadataUpgradeable).interfaceId] = true;

        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();

        sf.royaltiesEngineContractAddress = newRoyaltiesEngineContractAddress;
        sf.delegateRegistryContractAddress = newDelegateRegistryContractAddress;
        sf.seaportContractAddress = newSeaportContractAddress;
        sf.wethContractAddress = newWethContractAddress;
    }

    /// @inheritdoc ISellerFinancingAdmin
    function updateRoyaltiesEngineContractAddress(
        address newRoyaltiesEngineContractAddress
    ) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newRoyaltiesEngineContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.royaltiesEngineContractAddress = newRoyaltiesEngineContractAddress;
    }

    /// @inheritdoc ISellerFinancingAdmin
    function updateDelegateRegistryContractAddress(
        address newDelegateRegistryContractAddress
    ) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newDelegateRegistryContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.delegateRegistryContractAddress = newDelegateRegistryContractAddress;
    }

    /// @inheritdoc ISellerFinancingAdmin
    function updateSeaportContractAddress(address newSeaportContractAddress) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newSeaportContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.seaportContractAddress = newSeaportContractAddress;
    }

    /// @inheritdoc ISellerFinancingAdmin
    function updateWethContractAddress(address newWethContractAddress) external {
        LibDiamond.enforceIsContractOwner();
        _requireNonZeroAddress(newWethContractAddress);
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.wethContractAddress = newWethContractAddress;
    }

    /// @inheritdoc ISellerFinancing
    function royaltiesEngineContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.royaltiesEngineContractAddress;
    }

    /// @inheritdoc ISellerFinancing
    function delegateRegistryContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.delegateRegistryContractAddress;
    }

    /// @inheritdoc ISellerFinancing
    function seaportContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.seaportContractAddress;
    }

    /// @inheritdoc ISellerFinancing
    function wethContractAddress() external view returns (address) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return sf.wethContractAddress;
    }

    function pause() external {
        LibDiamond.enforceIsContractOwner();
        _pause();
    }

    function unpause() external {
        LibDiamond.enforceIsContractOwner();
        _unpause();
    }

    function pauseSanctions() external {
        LibDiamond.enforceIsContractOwner();
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.sanctionsPause = true;
    }

    function unpauseSanctions() external {
        LibDiamond.enforceIsContractOwner();
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        sf.sanctionsPause = false;
    }

    /// @inheritdoc ISellerFinancing
    function getOfferHash(Offer memory offer) public view returns (bytes32) {
    return _getOfferHash(offer);
    }

    /// @inheritdoc ISellerFinancing
    function getOfferSigner(
        Offer memory offer,
        bytes memory signature
    ) public view override returns (address) {
        return _getOfferSigner(offer, signature);
    }

    /// @inheritdoc ISellerFinancing
    function getOfferSignatureStatus(bytes memory signature) external view returns (bool) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getOfferSignatureStatus(signature, sf);
    }

    /// @inheritdoc ISellerFinancing
    function getCollectionOfferCount(bytes memory signature) public view returns (uint64 count) {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getCollectionOfferCount(signature, sf);
    }

    /// @inheritdoc ISellerFinancing
    function withdrawOfferSignature(Offer memory offer, bytes memory signature) external {
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        _requireAvailableSignature(signature, sf);
        address signer = _getOfferSigner(offer, signature);
        _requireSigner(signer, msg.sender);
        _markSignatureUsed(offer, signature, sf);
    }

    /// @inheritdoc ISellerFinancing
    function buyWithSellerFinancing(
        Offer memory offer,
        bytes calldata signature,
        uint256 nftId
    ) external payable whenNotPaused nonReentrant {
        // validate offerType
        _requireExpectedOfferType(offer, OfferType.SELLER_FINANCING);
        // requireSufficientMsgValue
        if (msg.value < offer.downPaymentAmount) {
            revert InsufficientMsgValue(msg.value, offer.downPaymentAmount);
        }
        // if msg.value is too high, return excess value
        if (msg.value > offer.downPaymentAmount) {
            payable(msg.sender).sendValue(msg.value - offer.downPaymentAmount);
        }

        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();


        // add check that offer.item.itemType is either 721 or 1155
        // add check that offer.terms.itemType is either NATIVE or 20
        address seller = _commonLoanChecks(offer, signature, msg.sender, nftId, sf);

        // transfer nft from seller to this contract, revert on failure
        _transferCollateral(offer.nftContractAddress, nftId, seller, address(this));

        // add loop to pay out marketplaceRecipients

        uint256 totalRoyaltiesPaid = _payRoyalties(
            offer.nftContractAddress,
            nftId,
            msg.sender,
            offer.downPaymentAmount,
            sf
        );

        // payout seller
        payable(seller).sendValue(offer.downPaymentAmount - totalRoyaltiesPaid);

        _executeLoan(offer, signature, msg.sender, seller, nftId, sf);
    }

    // add buyNow function, probably in separate facet

    /// @inheritdoc ISellerFinancing
    function makePayment(
        address nftContractAddress,
        uint256 nftId
    ) external payable whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        // make payment
        address buyer = _makePayment(nftContractAddress, nftId, msg.value, sf);
        // transfer nft to buyer if loan closed
        if (buyer != address(0)) {
            _transferCollateral(nftContractAddress, nftId, address(this), buyer);
        }
    }

// add protocol fee to this transaction, if first payment in period charge bps on remainingPrincipal at start of payment
    function _makePayment(
        address nftContractAddress,
        uint256 nftId,
        uint256 amountReceived,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal returns (address buyer) {
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId, sf);
        // get buyer
        address buyerAddress = ownerOf(loan.borrowerNftId);
        // get seller
        address sellerAddress = ownerOf(loan.lenderNftId);

        _requireIsNotSanctioned(buyerAddress, sf);
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
            payable(buyerAddress).sendValue(amountReceived - totalPossiblePayment);
            // adjust amountReceived value
            amountReceived = totalPossiblePayment;
        }

        uint256 totalRoyaltiesPaid = _payRoyalties(
            nftContractAddress,
            nftId,
            buyerAddress,
            amountReceived,
            sf
        );

        // payout seller
        _conditionalSendValue(sellerAddress, buyerAddress, amountReceived - totalRoyaltiesPaid, sf);

        // update loan struct
        loan.remainingPrincipal -= uint128(amountReceived - periodInterest);

        // check if remainingPrincipal is 0
        if (loan.remainingPrincipal == 0) {
            // if principal == 0 set nft transfer address to the buyer
            buyer = buyerAddress;
            // remove buyer delegate.cash delegation
            IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
                buyerAddress,
                nftContractAddress,
                nftId,
                false
            );
            // burn buyer nft
            _burn(loan.borrowerNftId);
            // burn seller nft
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
            // delete buyer nft id pointer
            delete sf.underlyingNfts[loan.borrowerNftId];
            // delete seller nft id pointer
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

    /// @inheritdoc ISellerFinancing
    function seizeAsset(
        address nftContractAddress,
        uint256 nftId
    ) external whenNotPaused nonReentrant {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId, sf);
        // get buyer
        address buyerAddress = ownerOf(loan.borrowerNftId);
        // get seller
        address sellerAddress = ownerOf(loan.lenderNftId);

        _requireIsNotSanctioned(sellerAddress, sf);
        // requireMsgSenderIsSeller
        _requireMsgSenderIsValidCaller(sellerAddress);
        // requireLoanInDefault
        if (_currentTimestamp32() < loan.periodEndTimestamp) {
            revert LoanNotInDefault();
        }

        // remove buyer delegate.cash delegation
        IDelegationRegistry(sf.delegateRegistryContractAddress).delegateForToken(
            buyerAddress,
            nftContractAddress,
            nftId,
            false
        );

        // burn buyer nft
        _burn(loan.borrowerNftId);

        // burn seller nft
        _burn(loan.lenderNftId);

        //emit asset seized event
        emit AssetSeized(nftContractAddress, nftId, loan);

        // close loan
        delete sf.loans[nftContractAddress][nftId];

        // transfer NFT from this contract to the seller address
        _transferCollateral(nftContractAddress, nftId, address(this), sellerAddress);
    }

    /// @inheritdoc ISellerFinancing
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
        // get buyer
        address buyerAddress = ownerOf(loan.borrowerNftId);

        _requireIsNotSanctioned(msg.sender, sf);
        // requireMsgSenderIsBuyer
        _requireMsgSenderIsValidCaller(buyerAddress);
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

        // make payment to close the loan and transfer remainder to the buyer
        _makePayment(nftContractAddress, nftId, saleAmountReceived, sf);

        // emit instant sell event
        emit InstantSell(nftContractAddress, nftId, saleAmountReceived);
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

    /// @inheritdoc ISellerFinancing
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
            // calculate % interest to be paid to seller
            if (loan.periodInterestRateBps != 0) {
                periodInterest =
                    ((loan.remainingPrincipal * loan.periodInterestRateBps) / NiftyApesStorage.BASE_BPS) *
                    numPeriodsPassed;
            }

            minimumPayment = minimumPrincipalPayment + periodInterest;
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

    function _payRoyalties(
        address nftContractAddress,
        uint256 nftId,
        address from,
        uint256 amount,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) private returns (uint256 totalRoyaltiesPaid) {
        // query royalty recipients and amounts
        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            sf.royaltiesEngineContractAddress
        ).getRoyaltyView(nftContractAddress, nftId, amount);

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                _conditionalSendValue(recipients[i], from, amounts[i], sf);
                totalRoyaltiesPaid += amounts[i];
            }
        }
    }

    /// @dev If "to" is a contract that doesn't accept ETH, send value back to "from" and continue
    /// otherwise "to" could force a default by sending bearer nft to contract that does not accept ETH
    function _conditionalSendValue(
        address to,
        address from,
        uint256 amount,
        NiftyApesStorage.SellerFinancingStorage storage sf
    ) internal {
        if (address(this).balance < amount) {
            revert InsufficientBalance(amount, address(this).balance);
        }

        // check if to is sanctioned
        bool isToSanctioned;
        if (!sf.sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(NiftyApesStorage.SANCTIONS_CONTRACT);
            isToSanctioned = sanctionsList.isSanctioned(to);
        }

        // if sanctioned, return value to from
        if (isToSanctioned) {
            (bool fromSuccess, ) = from.call{ value: amount }("");
            // require ETH is successfully sent to either to or from
            // we do not want ETH hanging in contract.
            if (!fromSuccess) {
                revert ConditionSendValueFailed(from, to, amount);
            }
        } else {
            // attempt to send value to to
            (bool toSuccess, ) = to.call{ value: amount }("");

            // if send fails, return vale to from
            if (!toSuccess) {
                (bool fromSuccess, ) = from.call{ value: amount }("");
                // require ETH is successfully sent to either to or from
                // we do not want ETH hanging in contract.
                if (!fromSuccess) {
                    revert ConditionSendValueFailed(from, to, amount);
                }
            }
        }
    }

    // Should these functions take a loanId or simply the ticketId. Having it with a address and id in the mapping identifies the nft more simply...

    /// @inheritdoc ISellerFinancing
    function getLoan(
        address nftContractAddress,
        uint256 nftId
    ) external view returns (Loan memory) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getLoan(nftContractAddress, nftId, sf);
    }

    /// @inheritdoc ISellerFinancing
    function getUnderlyingNft(
        uint256 sellerFinancingTicketId
    ) external view returns (address nftContractAddress, uint256 nftId) {
        // get SellerFinancing storage
        NiftyApesStorage.SellerFinancingStorage storage sf = NiftyApesStorage.sellerFinancingStorage();
        return _getUnderlyingNft(sellerFinancingTicketId, sf);
    }
}
