//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";
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
import "./interfaces/sellerFinancing/ISellerFinancing.sol";
import "./interfaces/sanctions/SanctionsList.sol";
import "./interfaces/royaltyRegistry/IRoyaltyEngineV1.sol";
import "./flashClaim/interfaces/IFlashClaimReceiver.sol";
import "./interfaces/seaport/ISeaport.sol";
import "./lib/ECDSABridge.sol";

/// @title NiftyApes Seller Financing
/// @custom:version 1.0
/// @author captnseagraves (captnseagraves.eth)
/// @custom:contributor zishansami102 (zishansami.eth)
/// @custom:contributor zjmiller (zjmiller.eth)
contract NiftyApesSellerFinancing is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721HolderUpgradeable,
    ISellerFinancing
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @notice The base value for fees in the protocol.
    uint256 private constant MAX_BPS = 10_000;

    /// @dev Constant typeHash for EIP-712 hashing of Offer struct
    ///      If the Offer struct shape changes, this will need to change as well.
    bytes32 private constant _OFFER_TYPEHASH =
        keccak256(
            "Offer(uint128 price,uint128 downPaymentAmount,uint128 minimumPrincipalPerPeriod,uint256 nftId,address nftContractAddress,address creator,uint32 periodInterestRateBps,uint32 periodDuration,uint32 expiration)"
        );

    // increaments by two for each loan, once for buyerNftId, once for sellerNftId
    uint256 private loanNftNonce;

    /// @dev The stored address for the royalties engine
    address private royaltiesEngineAddress;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    /// @dev A mapping for a NFT to a loan .
    ///      The mapping has to be broken into two parts since an NFT is denominated by its address (first part)
    ///      and its nftId (second part) in our code base.
    mapping(address => mapping(uint256 => Loan)) private _loans;

    /// @dev A mapping to mark a signature as used.
    ///      The mapping allows users to withdraw offers that they made by signature.
    mapping(bytes => bool) private _cancelledOrFinalized;

    // Mapping owner to nftContractAddress to token count
    mapping(address => mapping(address => uint256)) private _balances;

    // Mapping from owner to nftContractAddress to list of owned token IDs
    mapping(address => mapping(address => mapping(uint256 => uint256))) private _ownedTokens;

    // Mapping from nftContractAddress to token ID to index of the owner tokens list
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensIndex;

    // Address of the seaport contract
    address public seaportContractAddress;

    // Address of the weth contract
    address public wethContractAddress;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting storage.
    uint256[498] private __gap;

    /// @notice The initializer for the NiftyApes protocol.
    ///         NiftyApes is intended to be deployed behind a proxy and thus needs to initialize
    ///         its state outside of a constructor.
    function initialize(
        address newRoyaltiesEngineAddress,
        address newSeaportContractAddress,
        address newWethContractAddress
    ) public initializer {
        EIP712Upgradeable.__EIP712_init("NiftyApes_SellerFinancing", "0.0.1");
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
        ERC721Upgradeable.__ERC721_init("NiftyApes Seller Financing Tickets", "BANANAS");

        royaltiesEngineAddress = newRoyaltiesEngineAddress;
        seaportContractAddress = newSeaportContractAddress;
        wethContractAddress = newWethContractAddress;
    }

    /// @inheritdoc ISellerFinancingAdmin
    function updateSeaportContractAddress(address newSeaportContractAddress) external onlyOwner {
        _requireNonZeroAddress(newSeaportContractAddress);
        seaportContractAddress = newSeaportContractAddress;
    }

    /// @inheritdoc ISellerFinancingAdmin
    function updateWethContractAddress(address newWethContractAddress) external onlyOwner {
        _requireNonZeroAddress(newWethContractAddress);
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

    /// @inheritdoc ISellerFinancing
    function getOfferHash(Offer memory offer) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _OFFER_TYPEHASH,
                        offer.price,
                        offer.downPaymentAmount,
                        offer.minimumPrincipalPerPeriod,
                        offer.nftId,
                        offer.nftContractAddress,
                        offer.creator,
                        offer.periodInterestRateBps,
                        offer.periodDuration,
                        offer.expiration
                    )
                )
            );
    }

    /// @inheritdoc ISellerFinancing
    function getOfferSigner(
        Offer memory offer,
        bytes memory signature
    ) public view override returns (address) {
        return ECDSABridge.recover(getOfferHash(offer), signature);
    }

    /// @inheritdoc ISellerFinancing
    function getOfferSignatureStatus(bytes memory signature) external view returns (bool) {
        return _cancelledOrFinalized[signature];
    }

    /// @inheritdoc ISellerFinancing
    function withdrawOfferSignature(
        Offer memory offer,
        bytes memory signature
    ) external whenNotPaused {
        _requireAvailableSignature(signature);
        address signer = getOfferSigner(offer, signature);
        _requireSigner(signer, msg.sender);
        _markSignatureUsed(offer, signature);
    }

    /// @inheritdoc ISellerFinancing
    function buyWithFinancing(
        Offer memory offer,
        bytes calldata signature,
        address buyer
    ) external payable whenNotPaused nonReentrant {
        // instantiate loan
        Loan storage loan = _getLoan(offer.nftContractAddress, offer.nftId);
        // get seller
        address seller = getOfferSigner(offer, signature);

        _require721Owner(offer.nftContractAddress, offer.nftId, seller);
        _requireAvailableSignature(signature);
        _requireIsNotSanctioned(seller);
        _requireIsNotSanctioned(buyer);
        _requireIsNotSanctioned(msg.sender);
        _requireOfferNotExpired(offer);
        // requireOfferisValid
        _requireNonZeroAddress(offer.nftContractAddress);
        // require1MinsMinimumDuration
        if (offer.periodDuration < 1 minutes) {
            revert InvalidPeriodDuration();
        }
        // requireSufficientMsgValue
        if (msg.value < offer.downPaymentAmount) {
            revert InsufficientMsgValue(msg.value, offer.downPaymentAmount);
        }
        // requireDownPaymentLessThanOfferPrice
        if (offer.price <= offer.downPaymentAmount) {
            revert DownPaymentGreaterThanOrEqualToOfferPrice(offer.downPaymentAmount, offer.price);
        }
        // requireMinimumPrincipalLessThanTotalPrincipal
        if ((offer.price - offer.downPaymentAmount) < offer.minimumPrincipalPerPeriod) {
            revert InvalidMinimumPrincipalPerPeriod(
                offer.minimumPrincipalPerPeriod,
                (offer.price - offer.downPaymentAmount)
            );
        }
        // requireNotSellerFinancingTicket
        if (offer.nftContractAddress == address(this)) {
            revert CannotBuySellerFinancingTicket();
        }

        // mark signature as used
        _markSignatureUsed(offer, signature);

        // if msg.value is too high, return excess value
        if (msg.value > offer.downPaymentAmount) {
            payable(buyer).sendValue(msg.value - offer.downPaymentAmount);
        }

        uint256 totalRoyaltiesPaid = _payRoyalties(
            offer.nftContractAddress,
            offer.nftId,
            buyer,
            offer.downPaymentAmount
        );

        // payout seller
        payable(seller).sendValue(offer.downPaymentAmount - totalRoyaltiesPaid);

        // mint buyer nft
        uint256 buyerNftId = loanNftNonce;
        loanNftNonce++;
        _safeMint(buyer, buyerNftId);
        _setTokenURI(
            buyerNftId,
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(offer.nftId)
        );

        // mint seller nft
        uint256 sellerNftId = loanNftNonce;
        loanNftNonce++;
        _safeMint(seller, sellerNftId);

        // create loan
        _createLoan(loan, offer, sellerNftId, buyerNftId, (offer.price - offer.downPaymentAmount));

        // transfer nft from seller to this contract, revert on failure
        _transferNft(offer.nftContractAddress, offer.nftId, seller, address(this));

        // enable view based ownership of the purchased NFT
        _addLoanToOwnerEnumeration(buyer, offer.nftContractAddress, offer.nftId);

        // emit loan executed event
        emit LoanExecuted(offer.nftContractAddress, offer.nftId, signature, loan);
    }

    /// @inheritdoc ISellerFinancing
    function makePayment(
        address nftContractAddress,
        uint256 nftId
    ) external payable whenNotPaused nonReentrant {
        // make payment
        address buyer = _makePayment(nftContractAddress, nftId, msg.value);
        // transfer nft to buyer if loan closed
        if (buyer != address(0)) {
            _transferNft(nftContractAddress, nftId, address(this), buyer);
        }
    }

    function _makePayment(
        address nftContractAddress,
        uint256 nftId,
        uint256 amountReceived
    ) internal returns (address buyer) {
        // instatiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        // get buyer
        address buyerAddress = ownerOf(loan.buyerNftId);
        // get seller
        address sellerAddress = ownerOf(loan.sellerNftId);

        _requireIsNotSanctioned(buyerAddress);
        _requireIsNotSanctioned(msg.sender);
        // requireLoanNotInHardDefault
        _requireLoanNotInHardDefault(loan.periodEndTimestamp + loan.periodDuration);

        // get minimum payment and period interest values
        (uint256 totalMinimumPayment, uint256 periodInterest) = calculateMinimumPayment(loan);

        // caculate the total possible payment
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
            amountReceived
        );

        // payout seller
        _conditionalSendValue(sellerAddress, buyerAddress, amountReceived - totalRoyaltiesPaid);

        // update loan struct
        loan.remainingPrincipal -= uint128(amountReceived - periodInterest);

        // check if remianingPrincipal is 0
        if (loan.remainingPrincipal == 0) {
            // if principal == 0 set nft transfer address to the buyer
            buyer = buyerAddress;
            _removeLoanFromOwnerEnumeration(buyerAddress, nftContractAddress, nftId);
            // burn buyer nft
            _burn(loan.buyerNftId);
            // burn seller nft
            _burn(loan.sellerNftId);
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
            // delete loan
            delete _loans[nftContractAddress][nftId];
        }
        //else emit paymentMade event and update loan
        else {
            // if in the current period, else prior to period begin and end should remain the same
            if (_currentTimestamp32() >= loan.periodBeginTimestamp) {
                uint256 numPeriodsPassed = ((_currentTimestamp32() - loan.periodBeginTimestamp) /
                    loan.periodDuration) + 1;
                // increment the currentperiodBegin and End Timestamps equal to the periodDuration times numPeriodsPassed
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
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        // get buyer
        address buyerAddress = ownerOf(loan.buyerNftId);
        // get seller
        address sellerAddress = ownerOf(loan.sellerNftId);

        _requireIsNotSanctioned(sellerAddress);
        // requireMsgSenderIsSeller
        _requireMsgSenderIsValidCaller(sellerAddress);
        // requireLoanInDefault
        if (_currentTimestamp32() < loan.periodEndTimestamp) {
            revert LoanNotInDefault();
        }

        // transfer NFT from this contract to the seller address
        _transferNft(nftContractAddress, nftId, address(this), sellerAddress);

        // remove buyers view based ownership of the purchased NFT
        _removeLoanFromOwnerEnumeration(buyerAddress, nftContractAddress, nftId);

        // burn buyer nft
        _burn(loan.buyerNftId);

        // burn seller nft
        _burn(loan.sellerNftId);

        //emit asset seized event
        emit AssetSeized(nftContractAddress, nftId, loan);

        // close loan
        delete _loans[nftContractAddress][nftId];
    }

    /// @inheritdoc ISellerFinancing
    function instantSell(
        address nftContractAddress,
        uint256 nftId,
        uint256 minProfitAmount,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // instantiate loan
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        // get buyer
        address buyerAddress = ownerOf(loan.buyerNftId);

        _requireIsNotSanctioned(msg.sender);
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
            data
        );

        // make payment to close the loan and transfer remainder to the buyer
        _makePayment(nftContractAddress, nftId, saleAmountReceived);

        // emit instant sell event
        emit InstantSell(nftContractAddress, nftId, saleAmountReceived);
    }

    function _sellAsset(
        address nftContractAddress,
        uint256 nftId,
        uint256 minSaleAmount,
        bytes calldata data
    ) private returns (uint256 saleAmountReceived) {
        // approve the NFT for Seaport conduit
        IERC721Upgradeable(nftContractAddress).approve(seaportContractAddress, nftId);

        // decode seaport order data
        (ISeaport.Order memory order, bytes32 fulfillerConduitKey) = abi.decode(
            data,
            (ISeaport.Order, bytes32)
        );

        // validate order
        _validateSaleOrder(order, nftContractAddress, nftId);

        // instantiate weth
        IERC20Upgradeable asset = IERC20Upgradeable(wethContractAddress);

        // calculate totalConsiderationAmount
        uint256 totalConsiderationAmount;
        for (uint256 i = 1; i < order.parameters.totalOriginalConsiderationItems; i++) {
            totalConsiderationAmount = order.parameters.consideration[i].endAmount;
        }

        // set allowance for seaport to transferFrom this contract during .fulfillOrder()
        asset.approve(seaportContractAddress, totalConsiderationAmount);

        // cache this contract eth balance before the sale
        uint256 contractBalanceBefore = address(this).balance;

        // execute sale on seport
        if (!ISeaport(seaportContractAddress).fulfillOrder(order, fulfillerConduitKey)) {
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

        // calculate saleAmountReceived
        saleAmountReceived = address(this).balance - contractBalanceBefore;

        // check amount recieved is more than minSaleAmount
        if (saleAmountReceived < minSaleAmount) {
            revert InsufficientAmountReceivedFromSale(saleAmountReceived, minSaleAmount);
        }
    }

    /// @inheritdoc ISellerFinancing
    function flashClaim(
        address receiverAddress,
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // get loan
        Loan storage loan = _getLoan(nftContractAddress, nftId);

        _requireNftOwner(loan);
        _requireIsNotSanctioned(msg.sender);

        // instantiate receiver contract
        IFlashClaimReceiver receiver = IFlashClaimReceiver(receiverAddress);

        // transfer NFT
        _transferNft(nftContractAddress, nftId, address(this), receiverAddress);

        // execute firewalled external arbitrary functionality
        // function must approve this contract to transferFrom NFT in order to return to lending.sol
        if (!receiver.executeOperation(msg.sender, nftContractAddress, nftId, data)) {
            revert ExecuteOperationFailed();
        }

        // transfer nft back to this contract, revert if transfer fails
        _transferNft(nftContractAddress, nftId, receiverAddress, address(this));

        // emit flash claim event
        emit FlashClaim(nftContractAddress, nftId, receiverAddress);
    }

    /// @inheritdoc ISellerFinancing
    function balanceOf(address owner, address nftContractAddress) public view returns (uint256) {
        _requireNonZeroAddress(owner);
        return _balances[owner][nftContractAddress];
    }

    /// @inheritdoc ISellerFinancing
    function tokenOfOwnerByIndex(
        address owner,
        address nftContractAddress,
        uint256 index
    ) public view returns (uint256) {
        uint256 ownerTokenBalance = balanceOf(owner, nftContractAddress);
        if (index >= ownerTokenBalance) {
            revert InvalidIndex(index, ownerTokenBalance);
        }
        return _ownedTokens[owner][nftContractAddress][index];
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
                    ((loan.remainingPrincipal * loan.periodInterestRateBps) / MAX_BPS) *
                    numPeriodsPassed;
            }

            minimumPayment = minimumPrincipalPayment + periodInterest;
        }
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

    function _payRoyalties(
        address nftContractAddress,
        uint256 nftId,
        address from,
        uint256 amount
    ) private returns (uint256 totalRoyaltiesPaid) {
        // query royalty recipients and amounts
        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            royaltiesEngineAddress
        ).getRoyaltyView(nftContractAddress, nftId, amount);

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0) {
                _conditionalSendValue(recipients[i], from, amounts[i]);
                totalRoyaltiesPaid += amounts[i];
            }
        }
    }

    /// @dev If "to" is a contract that doesnt except ETH, send value back to "from" and continue
    /// otherwise "to" could force a default by sending bearer nft to contract that does not accept ETH
    function _conditionalSendValue(address to, address from, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert InsufficientBalance(amount, address(this).balance);
        }

        (bool toSuccess, ) = to.call{ value: amount }("");

        if (!toSuccess) {
            (bool fromSuccess, ) = from.call{ value: amount }("");
            // require ETH is sucessfully sent to either to or from
            // we do not want ETH hanging in contract.
            if (!fromSuccess) {
                revert ConditionSendValueFailed(from, to, amount);
            }
        }
    }

    /// @inheritdoc ISellerFinancing
    function getLoan(
        address nftContractAddress,
        uint256 nftId
    ) external view returns (Loan memory) {
        return _getLoan(nftContractAddress, nftId);
    }

    function _getLoan(
        address nftContractAddress,
        uint256 nftId
    ) private view returns (Loan storage) {
        return _loans[nftContractAddress][nftId];
    }

    function _createLoan(
        Loan storage loan,
        Offer memory offer,
        uint256 sellerNftId,
        uint256 buyerNftId,
        uint256 amount
    ) internal {
        loan.sellerNftId = sellerNftId;
        loan.buyerNftId = buyerNftId;
        loan.remainingPrincipal = uint128(amount);
        loan.periodEndTimestamp = _currentTimestamp32() + offer.periodDuration;
        loan.periodBeginTimestamp = _currentTimestamp32();
        loan.minimumPrincipalPerPeriod = offer.minimumPrincipalPerPeriod;
        loan.periodInterestRateBps = offer.periodInterestRateBps;
        loan.periodDuration = offer.periodDuration;
    }

    function _transferNft(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        IERC721Upgradeable(nftContractAddress).safeTransferFrom(from, to, nftId);
    }

    /// @dev Private function to add a token to this extension's ownership-tracking data structures.
    /// @param owner address representing the new owner of the given token ID
    /// @param nftContractAddress address nft collection address
    /// @param tokenId uint256 ID of the token to be added to the tokens list of the given address
    function _addLoanToOwnerEnumeration(
        address owner,
        address nftContractAddress,
        uint256 tokenId
    ) private {
        uint256 length = _balances[owner][nftContractAddress];
        _ownedTokens[owner][nftContractAddress][length] = tokenId;
        _ownedTokensIndex[nftContractAddress][tokenId] = length;
        _balances[owner][nftContractAddress] += 1;
    }

    /// @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
    /// while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
    /// gas optimizations e.g. when performing a transfer operation (avoiding double writes).
    /// This has O(1) time complexity, but alters the order of the _ownedTokens array.
    /// @param owner address representing the owner of the given token ID to be removed
    /// @param nftContractAddress address nft collection address
    /// @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
    function _removeLoanFromOwnerEnumeration(
        address owner,
        address nftContractAddress,
        uint256 tokenId
    ) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and then delete the last slot (swap and pop).

        uint256 lastTokenIndex = balanceOf(owner, nftContractAddress) - 1;
        uint256 tokenIndex = _ownedTokensIndex[nftContractAddress][tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[owner][nftContractAddress][lastTokenIndex];

            _ownedTokens[owner][nftContractAddress][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[nftContractAddress][lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[nftContractAddress][tokenId];
        delete _ownedTokens[owner][nftContractAddress][lastTokenIndex];

        // decrease the owner's collection balance by one
        _balances[owner][nftContractAddress] -= 1;
    }

    function _currentTimestamp32() internal view returns (uint32) {
        return SafeCastUpgradeable.toUint32(block.timestamp);
    }

    function _requireIsNotSanctioned(address addressToCheck) internal view {
        if (!_sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(SANCTIONS_CONTRACT);
            bool isToSanctioned = sanctionsList.isSanctioned(addressToCheck);
            if (isToSanctioned) {
                revert SanctionedAddress(addressToCheck);
            }
        }
    }

    function _requireAvailableSignature(bytes memory signature) public view {
        if (_cancelledOrFinalized[signature]) {
            revert SignatureNotAvailable(signature);
        }
    }

    function _requireOfferNotExpired(Offer memory offer) internal view {
        if (offer.expiration <= SafeCastUpgradeable.toUint32(block.timestamp)) {
            revert OfferExpired();
        }
    }

    function _require721Owner(
        address nftContractAddress,
        uint256 nftId,
        address owner
    ) internal view {
        if (IERC721Upgradeable(nftContractAddress).ownerOf(nftId) != owner) {
            revert NotNftOwner(nftContractAddress, nftId, owner);
        }
    }

    function _requireSigner(address signer, address expected) internal pure {
        if (signer != expected) {
            revert InvalidSigner(signer, expected);
        }
    }

    function _requireNftOwner(Loan storage loan) internal view {
        if (msg.sender != ownerOf(loan.buyerNftId)) {
            revert NotNftOwner(address(this), loan.buyerNftId, msg.sender);
        }
    }

    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }

    function _requireLoanNotInHardDefault(uint32 hardDefaultTimestamp) internal view {
        if (_currentTimestamp32() >= hardDefaultTimestamp) {
            revert SoftGracePeriodEnded();
        }
    }

    function _requireMsgSenderIsValidCaller(address expectedCaller) internal view {
        if(msg.sender != expectedCaller) {
            revert InvalidCaller(msg.sender, expectedCaller);
        }
    }

    function _markSignatureUsed(Offer memory offer, bytes memory signature) internal {
        _cancelledOrFinalized[signature] = true;

        emit OfferSignatureUsed(offer.nftContractAddress, offer.nftId, offer, signature);
    }

    function renounceOwnership() public override onlyOwner {}

    /// @notice This contract needs to accept ETH from NFT Sale
    receive() external payable {}
}
