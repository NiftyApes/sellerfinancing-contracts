//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "./interfaces/sellerFinancing/ISellerFinancing.sol";
import "./interfaces/seaport/ISeaport.sol";
import "./interfaces/sanctions/SanctionsList.sol";
import "./flashPurchase/interfaces/IFlashPurchaseReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./lib/ECDSABridge.sol";

/// @title NiftyApes Seller Financing
/// @custom:version 1.0
/// @author captnseagraves (captnseagraves.eth)

contract NiftyApesSellerFinancing is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable,
    ISellerFinancing
{
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @notice The base value for fees in the protocol.
    uint256 private constant MAX_BPS = 10_000;

    /// @dev Constant typeHash for EIP-712 hashing of Offer struct
    ///      If the Offer struct shape changes, this will need to change as well.
    bytes32 private constant _OFFER_TYPEHASH =
        keccak256(
            "Offer(address creator,uint32 downPaymentBps,uint32 payPeriodPrincipalBps,uint32 payPeriodInterestRateBps,uint32 payPeriodDuration,nftContractAddress,uint256 nftId,address asset,uint32 expiration)"
        );

    /// @dev A mapping for storing the seaport listing with its hash as the key
    mapping(bytes32 => SeaportListing) private _orderHashToListing;

    // instead of address to nftId to struct, could create a loanHash from the address ID and loan ID/Nonce,
    // and use that as the pointer to the loan Struct. - ks

    /// @dev A mapping for a NFT to a loan .
    ///      The mapping has to be broken into two parts since an NFT is denominated by its address (first part)
    ///      and its nftId (second part) in our code base.
    mapping(address => mapping(uint256 => Loan)) private _loans;

    /// @dev A mapping to mark a signature as used.
    ///      The mapping allows users to withdraw offers that they made by signature.
    mapping(bytes => bool) private _cancelledOrFinalized;

    /// @dev The status of sanctions checks. Can be set to false if oracle becomes malicious.
    bool internal _sanctionsPause;

    // could mint an NFT and have these in an inherited contract - ks

    // Mapping owner to nftContractAddress to token count
    mapping(address => mapping(address => uint256)) private _balances;

    // Mapping from owner to nftContractAddress to list of owned token IDs
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        private _ownedTokens;

    // Mapping from nftContractAddress to token ID to index of the owner tokens list
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensIndex;

    uint16 public protocolInterestBps;

    address public seaportContractAddress;

    address public seaportZone;

    address public seaportFeeRecepient;

    bytes32 public seaportZoneHash;

    bytes32 public seaportConduitKey;

    address public seaportConduit;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting storage.
    uint256[500] private __gap;

    /// @notice The initializer for the NiftyApes protocol.
    ///         NiftyApes is intended to be deployed behind a proxy and thus needs to initialize
    ///         its state outside of a constructor.
    function initialize() public initializer {
        EIP712Upgradeable.__EIP712_init("NiftyApes_SellerFinancing", "0.0.1");
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        // 21 bps == 2.52% APR
        protocolInterestBps = 21;

        seaportZone = 0x004C00500000aD104D7DBd00e3ae0A5C00560C00;
        seaportFeeRecepient = 0x0000a26b00c1F0DF003000390027140000fAa719;
        seaportZoneHash = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        seaportConduitKey = bytes32(
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
        );
        seaportConduit = 0x1E0049783F008A0085193E00003D00cd54003c71;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getOfferHash(Offer memory offer) public view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        _OFFER_TYPEHASH,
                        offer.creator,
                        offer.downPaymentBps,
                        offer.payPeriodPrincipalBps,
                        offer.payPeriodInterestRateBps,
                        offer.payPeriodDuration,
                        offer.gracePeriodDuration,
                        offer.nftContractAddress,
                        offer.nftId,
                        offer.asset,
                        offer.expiration
                    )
                )
            );
    }

    function getOfferSigner(Offer memory offer, bytes memory signature)
        public
        view
        override
        returns (address)
    {
        return ECDSABridge.recover(getOfferHash(offer), signature);
    }

    function getOfferSignatureStatus(bytes memory signature)
        external
        view
        returns (bool)
    {
        return _cancelledOrFinalized[signature];
    }

    function withdrawOfferSignature(Offer memory offer, bytes memory signature)
        external
        whenNotPaused
    {
        _requireAvailableSignature(signature);
        _requireSignature65(signature);
        address signer = getOfferSigner(offer, signature);
        _requireSigner(signer, msg.sender);
        _requireOfferCreator(offer.creator, msg.sender);
        _markSignatureUsed(offer, signature);
    }

    function buyNowWithFinancing(Offer memory offer, bytes memory signature)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        address seller = getOfferSigner(offer, signature);
        _require721Owner(offer.nftContractAddress, offer.nftId, seller);
        _requireAvailableSignature(signature);
        _requireSignature65(signature);
        _requireIsNotSanctioned(seller);
        _requireIsNotSanctioned(msg.sender);
        // requireOfferisValid
        require(offer.nftContractAddress != address(0), "00004");
        _requireOfferNotExpired(offer);
        Loan storage loan = _getLoan(offer.nftContractAddress, offer.nftId);
        // requireNoOpenLoan
        require(loan.periodBeginTimestamp == 0, "00006");

        // transfer of down payment
        uint256 downPaymentAmount = (offer.reservePrice * MAX_BPS) /
            offer.downPaymentBps;

        // this transfer of value must go from buyer to seller directly. this function currently only transfers to this contract address
        // it should also include the initial payment to the protocol
        if (offer.asset == address(0)) {
            require(msg.value >= downPaymentAmount, "00047");
            if (msg.value > downPaymentAmount) {
                payable(msg.sender).sendValue(msg.value - downPaymentAmount);
            }
            payable(seller).sendValue(downPaymentAmount);
        } else {
            IERC20Upgradeable asset = IERC20Upgradeable(offer.asset);
            asset.safeTransferFrom(msg.sender, seller, downPaymentAmount);
        }

        // create loan
        _createLoan(
            loan,
            offer,
            seller,
            msg.sender,
            (offer.reservePrice - downPaymentAmount)
        );

        // Transfer nft from receiver contract to this contract as collateral, revert on failure
        _transferNft(
            offer.nftContractAddress,
            offer.nftId,
            seller,
            address(this)
        );

        _addTokenToOwnerEnumeration(
            msg.sender,
            offer.nftContractAddress,
            offer.nftId
        );

        emit LoanExecuted(offer.nftContractAddress, offer.nftId, seller, loan);
    }

    function makePayment(
        address nftContractAddress,
        uint256 nftId,
        uint256 amount
    ) external payable whenNotPaused nonReentrant {
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        _requireIsNotSanctioned(loan.buyer);
        _requireIsNotSanctioned(msg.sender);
        _requireOpenLoan(loan);

        // check the currentPayPeriodEndTimestamp
        if (_currentTimestamp32() > loan.periodEndTimestamp) {
            // if late increment latePayment counter
            loan.numLatePayments += 1;
        }

        // calculate the % of principal and interest that must be paid to the seller
        uint256 minimumPrincipalPayment = ((loan.totalPrincipal * MAX_BPS) /
            loan.payPeriodPrincipalBps);

        // if remainingPrincipal is less than minimumPrincipalPayment make minimum payment the remainder of the principal
        if (loan.remainingPrincipal < minimumPrincipalPayment) {
            minimumPrincipalPayment = loan.remainingPrincipal;
        }
        // calculate % interest to be paid to seller
        uint256 periodInterest = ((loan.remainingPrincipal * MAX_BPS) /
            loan.payPeriodInterestRateBps);
        // calculate % interest to be paid to protocol
        uint256 protocolInterest = ((loan.remainingPrincipal * MAX_BPS) /
            protocolInterestBps);

        uint256 totalMinimumPayment = minimumPrincipalPayment +
            periodInterest +
            protocolInterest;
        uint256 totalPossiblePayment = loan.remainingPrincipal +
            periodInterest +
            protocolInterest;

        // payout seller and protocol
        if (loan.asset == address(0)) {
            // set msgValue value
            uint256 msgValue = msg.value;
            //require msgValue to be larger than the total minimum payment
            require(msgValue >= totalMinimumPayment, "00047");
            // if msgValue is greater than the totalPossiblePayment send back the difference
            if (msgValue > totalPossiblePayment) {
                //send back value
                payable(loan.buyer).sendValue(msgValue - totalPossiblePayment);
                // adjust msgValue value
                msgValue = totalPossiblePayment;
            }

            // payout seller
            payable(loan.seller).sendValue(msgValue - protocolInterest);

            // payout owner
            payable(owner()).sendValue(msgValue - protocolInterest);

            // update loan struct
            loan.remainingPrincipal -
                (msgValue - periodInterest - protocolInterest);
        } else {
            //require amount to be larger than the total minimum payment
            require(amount >= totalMinimumPayment, "00047");
            // if amount is greater than the totalPossiblePayment adjust to only transfer the required amount
            if (amount > totalPossiblePayment) {
                amount = totalPossiblePayment;
            }

            IERC20Upgradeable asset = IERC20Upgradeable(loan.asset);
            // payout seller
            asset.safeTransferFrom(
                msg.sender,
                loan.seller,
                amount - protocolInterest
            );

            // payout owner
            asset.safeTransferFrom(msg.sender, owner(), protocolInterest);

            // if we had an affiliate payment it would go here

            // update loan struct
            loan.remainingPrincipal -
                (amount - periodInterest - protocolInterest);
        }

        // check if remianingPrincipal is 0
        if (loan.remainingPrincipal == 0) {
            // if principal == 0 transfer nft and end loan
            _transferNft(nftContractAddress, nftId, address(this), loan.buyer);
            //emit paymentMade event
            emit PaymentMade(nftContractAddress, nftId, amount, loan);
            // emit loan repaid event
            emit LoanRepaid(nftContractAddress, nftId, loan);

            // delete loan
            delete _loans[nftContractAddress][nftId];
        }
        //else emit paymentMade event and update loan
        else {
            // increment the currentPayPeriodBegin and End Timestamps equal to the payPeriodDuration
            loan.periodBeginTimestamp += loan.payPeriodDuration;
            loan.periodEndTimestamp += loan.payPeriodDuration;

            //emit paymentMade event
            emit PaymentMade(nftContractAddress, nftId, amount, loan);
        }
    }

    // currently callable by anyone, should it only be callable by the seller?
    function seizeAsset(address nftContractAddress, uint256 nftId)
        external
        whenNotPaused
        nonReentrant
    {
        Loan storage loan = _getLoan(nftContractAddress, nftId);

        _requireIsNotSanctioned(loan.seller);
        // require principal is not 0
        require(loan.remainingPrincipal != 0, "loan repaid");
        // requirePastGracePeriodOrMaxLatePayments
        require(
            _currentTimestamp32() >
                loan.periodEndTimestamp + loan.gracePeriodDuration ||
                loan.numLatePayments > loan.numLatePaymentsTolerance,
            "Asset not seizable"
        );

        address currentSeller = loan.seller;
        address currentBuyer = loan.buyer;

        emit AssetSeized(nftContractAddress, nftId, loan);
        delete _loans[nftContractAddress][nftId];
        _transferNft(nftContractAddress, nftId, address(this), currentSeller);
        _removeTokenFromOwnerEnumeration(
            currentBuyer,
            nftContractAddress,
            nftId
        );
    }

    function instantSell(
        address nftContractAddress,
        uint256 nftId,
        address receiver,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // require statements
        // get loan

        address buyer = _requireNftOwner(nftContractAddress, nftId);
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        //require buyer is msg.sender

        Loan memory loan = _getLoan(nftContractAddress, nftId);

        address loanAsset;
        if (loan.asset != address(0)) {
            loanAsset = loan.asset;
        }

        uint256 totalLoanPaymentAmount = _calculateTotalLoanPaymentAmount(loan);

        uint256 assetBalanceBefore = _getAssetBalance(loan.asset);

        // approve the NFT for Seaport conduit
        IERC721Upgradeable(nftContractAddress).approve(
            seaportContractAddress,
            nftId
        );

        // verify marketplace order

        (ISeaport.Order memory order, bytes32 fulfillerConduitKey) = abi.decode(
            data,
            (ISeaport.Order, bytes32)
        );
        _requireValidOrderAssets(order, nftContractAddress, nftId, loanAsset);

        // check that sellAmount is sufficient to pay off loan plus interest

        // execute sale

        require(
            ISeaport(seaportContractAddress).fulfillOrder(
                order,
                fulfillerConduitKey
            ),
            "00048"
        );

        uint256 assetBalanceAfter = _getAssetBalance(loan.asset);

        uint256 amountReceivedFromSale = assetBalanceAfter - assetBalanceBefore;

        // require assets received are enough to settle the loan
        require(amountReceivedFromSale >= totalLoanPaymentAmount, "00057");

        // payout seller and protocol
        if (loan.asset == address(0)) {
            // payout seller
            payable(loan.seller).sendValue(
                totalLoanPaymentAmount - protocolInterest
            );

            // payout owner
            payable(owner()).sendValue(protocolInterest);
        } else {
            IERC20Upgradeable asset = IERC20Upgradeable(loan.asset);
            // payout seller
            asset.safeTransferFrom(
                msg.sender,
                loan.seller,
                totalLoanPaymentAmount - protocolInterest
            );

            // payout owner
            asset.safeTransferFrom(msg.sender, owner(), protocolInterest);

            // if we had an affiliate payment it would go here
        }

        // if there is a profit in the sale, transfer funds to buyer
        if (amountReceivedFromSale > totalLoanPaymentAmount) {
            if (loan.asset == address(0)) {
                // payout buyer
                payable(buyer).sendValue(
                    amountReceivedFromSale - totalLoanPaymentAmount
                );
            } else {
                // payout owner
                asset.safeTransferFrom(
                    address(this),
                    buyer,
                    amountReceivedFromSale - totalLoanPaymentAmount
                );
            }
        }
        // emit sell event
        // delete loan
    }

    function listNftForSale(
        address nftContractAddress,
        uint256 nftId,
        uint256 listingPrice,
        uint256 listingStartTime,
        uint256 listingEndTime,
        uint256 salt
    ) external whenNotPaused nonReentrant returns (bytes32) {
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        uint256 seaportFeeAmount = listingPrice - (listingPrice * 39) / 40;

        // validate inputs and its price wrt listingEndTime
        _requireNftOwner(loan);
        _requireIsNotSanctioned(msg.sender);
        _requireOpenLoan(loan);
        _requireListingValueGreaterThanLoanRepaymentAmountUntilListingExpiry(
            loan,
            listingPrice,
            seaportFeeAmount
        );

        // construct Seaport Order
        ISeaport.Order[] memory order = _constructOrder(
            nftContractAddress,
            nftId,
            listingPrice,
            seaportFeeAmount,
            listingStartTime,
            listingEndTime,
            loan.asset,
            salt
        );
        // approve the NFT for Seaport address
        IERC721Upgradeable(nftContractAddress).approve(seaportConduit, nftId);

        // validate listing to Seaport
        ISeaport(seaportContractAddress).validate(order);
        // get orderHash by calling ISeaport.getOrderHash()
        bytes32 orderHash = _getOrderHash(order[0]);
        // validate order status by calling ISeaport.getOrderStatus(orderHash)
        (bool validated, , , ) = ISeaport(seaportContractAddress)
            .getOrderStatus(orderHash);
        require(validated, "00059");

        // store the listing with orderHash
        _orderHashToListing[orderHash] = SeaportListing(
            nftContractAddress,
            nftId,
            listingPrice - seaportFeeAmount
        );

        // emit orderHash with it's listing
        emit ListedOnSeaport(nftContractAddress, nftId, orderHash, loan);
        return orderHash;
    }

    function validateSaleAndWithdraw(
        address nftContractAddress,
        uint256 nftId,
        bytes32 orderHash
    ) external whenNotPaused nonReentrant {}

    function cancelNftListing(ISeaport.OrderComponents memory orderComponents)
        external
        whenNotPaused
        nonReentrant
    {}

    function flashClaim(
        address receiverAddress,
        address nftContractAddress,
        uint256 nftId,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // address nftOwner = _requireNftOwner(nftContractAddress, nftId);
        // _requireIsNotSanctioned(msg.sender);
        // _requireIsNotSanctioned(nftOwner);
        // // instantiate receiver contract
        // IFlashClaimReceiver receiver = IFlashClaimReceiver(receiverAddress);
        // // transfer NFT
        // _transferNft(
        //     nftContractAddress,
        //     nftId,
        //     receiverAddress
        // );
        // // execute firewalled external arbitrary functionality
        // // function must approve this contract to transferFrom NFT in order to return to lending.sol
        // require(
        //     receiver.executeOperation(
        //         msg.sender,
        //         nftContractAddress,
        //         nftId,
        //         data
        //     ),
        //     "00058"
        // );
        // // transfer nft back to Lending.sol and require return occurs
        // _transferNft(
        //     nftContractAddress,
        //     nftId,
        //     receiverAddress,
        //     lendingContractAddress
        // );
        // // emit event
        // emit FlashClaim(nftContractAddress, nftId, receiverAddress);
    }

    function balanceOf(address owner, address nftContractAddress)
        public
        view
        returns (uint256)
    {
        require(owner != address(0), "00035");
        return _balances[owner][nftContractAddress];
    }

    function tokenOfOwnerByIndex(
        address owner,
        address nftContractAddress,
        uint256 index
    ) public view returns (uint256) {
        require(index < balanceOf(owner, nftContractAddress), "00069");
        return _ownedTokens[owner][nftContractAddress][index];
    }

    function _getLoan(address nftContractAddress, uint256 nftId)
        internal
        view
        returns (Loan storage)
    {
        return _loans[nftContractAddress][nftId];
    }

    function _createLoan(
        Loan storage loan,
        Offer memory offer,
        address seller,
        address buyer,
        uint256 amount
    ) internal {
        loan.buyer = buyer;
        loan.seller = seller;
        loan.asset = offer.asset;
        loan.totalPrincipal = uint128(amount);
        loan.remainingPrincipal = uint128(amount);
        loan.periodEndTimestamp =
            _currentTimestamp32() +
            offer.payPeriodDuration;
        loan.periodBeginTimestamp = _currentTimestamp32();
        loan.downPaymentBps = offer.downPaymentBps;
        loan.payPeriodPrincipalBps = offer.payPeriodPrincipalBps;
        loan.payPeriodInterestRateBps = offer.payPeriodInterestRateBps;
        loan.payPeriodDuration = offer.payPeriodDuration;
        loan.gracePeriodDuration = offer.gracePeriodDuration;
        loan.numLatePaymentsTolerance = offer.numLatePaymentsTolerance;
        loan.numLatePayments = 0;
    }

    function _transferNft(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        IERC721Upgradeable(nftContractAddress).safeTransferFrom(
            from,
            to,
            nftId
        );
    }

    /// @dev Private function to add a token to this extension's ownership-tracking data structures.
    /// @param owner address representing the new owner of the given token ID
    /// @param nftContractAddress address nft collection address
    /// @param tokenId uint256 ID of the token to be added to the tokens list of the given address
    function _addTokenToOwnerEnumeration(
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
    function _removeTokenFromOwnerEnumeration(
        address owner,
        address nftContractAddress,
        uint256 tokenId
    ) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and then delete the last slot (swap and pop).

        uint256 lastTokenIndex = balanceOf(owner, nftContractAddress) - 1;
        uint256 tokenIndex = _ownedTokensIndex[nftContractAddress][tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[owner][nftContractAddress][
                lastTokenIndex
            ];

            _ownedTokens[owner][nftContractAddress][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[nftContractAddress][lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[nftContractAddress][tokenId];
        delete _ownedTokens[owner][nftContractAddress][lastTokenIndex];

        // decrease the owner's collection balance by one
        _balances[owner][nftContractAddress] -= 1;
    }

    function _requireListingValueGreaterThanLoanRepaymentAmountUntilListingExpiry(
        Loan memory loan,
        uint256 listingPrice,
        uint256 seaportFeeAmount
    ) internal view {
        require(
            listingPrice - seaportFeeAmount >=
                _calculateTotalLoanPaymentAmount(loan),
            "00060"
        );
    }

    function _calculateTotalLoanPaymentAmount(Loan memory loan)
        internal
        view
        returns (uint256 totalPayment)
    {
        // add remainingPrincipal
        totalPayment += loan.remainingPrincipal;
        // check if current timestamp is before or after the period begin timestamp
        // if after add interest payments for seller and protocol
        if (_currentTimestamp32() > loan.periodBeginTimestamp) {
            totalPayment +=
                // calculate % interest to be paid to seller
                ((loan.remainingPrincipal * MAX_BPS) /
                    loan.payPeriodInterestRateBps) +
                // calculate % interest to be paid to protocol
                ((loan.remainingPrincipal * MAX_BPS) / protocolInterestBps);
        }
    }

    function _getOrderHash(ISeaport.Order memory order)
        internal
        view
        returns (bytes32 orderHash)
    {
        // Derive order hash by supplying order parameters along with counter.
        orderHash = ISeaport(seaportContractAddress).getOrderHash(
            ISeaport.OrderComponents(
                order.parameters.offerer,
                order.parameters.zone,
                order.parameters.offer,
                order.parameters.consideration,
                order.parameters.orderType,
                order.parameters.startTime,
                order.parameters.endTime,
                order.parameters.zoneHash,
                order.parameters.salt,
                order.parameters.conduitKey,
                ISeaport(seaportContractAddress).getCounter(
                    order.parameters.offerer
                )
            )
        );
    }

    function _constructOrder(
        address nftContractAddress,
        uint256 nftId,
        uint256 listingPrice,
        uint256 seaportFeeAmount,
        uint256 listingStartTime,
        uint256 listingEndTime,
        address asset,
        uint256 randomSalt
    ) internal view returns (ISeaport.Order[] memory order) {
        ISeaport.ItemType considerationItemType = (
            asset == address(0)
                ? ISeaport.ItemType.NATIVE
                : ISeaport.ItemType.ERC20
        );
        address considerationToken = (asset == address(0) ? address(0) : asset);

        order = new ISeaport.Order[](1);
        order[0] = ISeaport.Order({
            parameters: ISeaport.OrderParameters({
                offerer: address(this),
                zone: seaportZone,
                offer: new ISeaport.OfferItem[](1),
                consideration: new ISeaport.ConsiderationItem[](2),
                orderType: ISeaport.OrderType.FULL_OPEN,
                startTime: listingStartTime,
                endTime: listingEndTime,
                zoneHash: seaportZoneHash,
                salt: randomSalt,
                conduitKey: seaportConduitKey,
                totalOriginalConsiderationItems: 2
            }),
            signature: bytes("")
        });
        order[0].parameters.offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: nftContractAddress,
            identifierOrCriteria: nftId,
            startAmount: 1,
            endAmount: 1
        });
        order[0].parameters.consideration[0] = ISeaport.ConsiderationItem({
            itemType: considerationItemType,
            token: considerationToken,
            identifierOrCriteria: 0,
            startAmount: listingPrice - seaportFeeAmount,
            endAmount: listingPrice - seaportFeeAmount,
            recipient: payable(address(this))
        });
        order[0].parameters.consideration[1] = ISeaport.ConsiderationItem({
            itemType: considerationItemType,
            token: considerationToken,
            identifierOrCriteria: 0,
            startAmount: seaportFeeAmount,
            endAmount: seaportFeeAmount,
            recipient: payable(seaportFeeRecepient)
        });
    }

    function _requireValidOrderAssets(
        ISeaport.Order memory order,
        address nftContractAddress,
        uint256 nftId,
        address loanAsset
    ) internal view {
        require(
            order.parameters.consideration[0].itemType ==
                ISeaport.ItemType.ERC721,
            "00067"
        );
        require(
            order.parameters.consideration[0].token == nftContractAddress,
            "00067"
        );
        require(
            order.parameters.consideration[0].identifierOrCriteria == nftId,
            "00067"
        );
        require(
            order.parameters.offer[0].itemType == ISeaport.ItemType.ERC20,
            "00067"
        );
        require(
            order.parameters.consideration[1].itemType ==
                ISeaport.ItemType.ERC20,
            "00067"
        );
        if (loanAsset == address(0)) {
            require(
                order.parameters.offer[0].token == wethContractAddress,
                "00067"
            );
            require(
                order.parameters.consideration[1].token == wethContractAddress,
                "00067"
            );
        } else {
            require(order.parameters.offer[0].token == loanAsset, "00067");
            require(
                order.parameters.consideration[1].token == loanAsset,
                "00067"
            );
        }
    }

    function _currentTimestamp32() internal view returns (uint32) {
        return SafeCastUpgradeable.toUint32(block.timestamp);
    }

    function _requireIsNotSanctioned(address addressToCheck) internal view {
        if (!_sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(SANCTIONS_CONTRACT);
            bool isToSanctioned = sanctionsList.isSanctioned(addressToCheck);
            require(!isToSanctioned, "00017");
        }
    }

    function _requireAvailableSignature(bytes memory signature) public view {
        require(!_cancelledOrFinalized[signature], "00032");
    }

    function _requireSignature65(bytes memory signature) public pure {
        require(signature.length == 65, "00003");
    }

    function _requireOfferNotExpired(Offer memory offer) internal view {
        require(
            offer.expiration > SafeCastUpgradeable.toUint32(block.timestamp),
            "00010"
        );
    }

    function _require721Owner(
        address nftContractAddress,
        uint256 nftId,
        address owner
    ) internal view {
        require(
            IERC721Upgradeable(nftContractAddress).ownerOf(nftId) == owner,
            "00021"
        );
    }

    function _requireSigner(address signer, address expected) internal pure {
        require(signer == expected, "00033");
    }

    function _requireOfferCreator(address signer, address expected)
        internal
        pure
    {
        require(signer == expected, "00024");
    }

    function _requireOfferDoesntExist(address offerCreator) internal pure {
        require(offerCreator == address(0), "00046");
    }

    function _requireOpenLoan(Loan storage loan) internal view {
        require(loan.remainingPrincipal != 0, "00007");
    }

    function _requireNftOwner(Loan storage loan) internal view {
        require(msg.sender == loan.buyer, "00021");
    }

    function _markSignatureUsed(Offer memory offer, bytes memory signature)
        internal
    {
        _cancelledOrFinalized[signature] = true;

        emit OfferSignatureUsed(
            offer.nftContractAddress,
            offer.nftId,
            offer,
            signature
        );
    }

    function renounceOwnership() public override onlyOwner {}
}
