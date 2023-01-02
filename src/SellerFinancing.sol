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

    /// @dev A mapping for a NFT to a loan auction.
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

    // TODO @captn: need to make sale offers (full value and with financing)
    // on marketplace at time of financing offer creation. Probably not smart contract work.

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

    function buyNowWithFinancingDirect(
        Offer memory offer,
        bytes memory signature
    ) external whenNotPaused nonReentrant {
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
        _arrangeAssetFromBuyer(msg.sender, offer.asset, downPaymentAmount);

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
        if (_currentTimestamp32() > periodEndTimestamp) {
            // if late increment latePayment counter
            numLatePayments += 1;
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
            //require it to be larger than the total minimum payment
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

            // update loan struct
            loan.remainingPricipal -
                (msgValue - periodInterest - protocolInterest);
        } else {
            require(amount >= totalMinimumPayment, "00047");
            // if amount is greater than the totalPossiblePayment adjust to only transfer the required amount
            if (amount > totalPossiblePayment) {
                amount = totalPossiblePayment;
            }

            IERC20Upgradeable asset = IERC20Upgradeable(offer.asset);
            asset.safeTransferFrom(
                msg.sender,
                loan.seller,
                amount - protocolInterest
            );
            asset.safeTransferFrom(msg.sender, owner(), protocolInterest);
            // if we had an affiliate payment it would go here
        }

        // increment the currentPayPeriodBegin and End Timestamps equal to the payPeriodDuration
        loan.periodBeginTimestamp += loan.payPeriodDuration;
        loan.periodEndTimestamp += loan.payPeriodDuration;

        // check if payment decrements principal to 0
        if ((amount - periodInterest - protocolInterest)) {}

        // if principal == 0 transfer nft and end loan
        _transferNft(nftContractAddress, nftId, address(this), loan.buyer);

        // update loan struct
    }

    function seizeAsset(address nftContractAddress, uint256 nftId)
        external
        whenNotPaused
        nonReentrant
    {
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        _requireIsNotSanctioned(loan.seller);

        // require principal is not 0
        // does this require statement serve this need?
        _requireOpenLoan(loan);

        // requirePastGracePeriodOrMaxLatePayments

        address currentLender = loan.seller;
        address nftOwner = loan.buyer;

        emit AssetSeized(nftContractAddress, nftId, loan);
        delete _loans[nftContractAddress][nftId];
        _transferNft(nftContractAddress, nftId, address(this), currentLender);
        _removeTokenFromOwnerEnumeration(nftOwner, nftContractAddress, nftId);
    }

    function buyNowWithFinancing3rdParty(
        Offer memory offer,
        bytes memory signature,
        address receiver,
        address buyer,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        address seller = getOfferSigner(offer, signature);
        _require721Owner(offer.nftContractAddress, offer.nftId, seller);
        // is this check sitll needed?
        _requireOfferCreator(offer.creator, seller);
        _requireAvailableSignature(signature);
        _requireSignature65(signature);
        // is offer.creator still needed in the offer struct?
        _requireIsNotSanctioned(offer.creator);
        _requireIsNotSanctioned(buyer);
        _requireIsNotSanctioned(receiver);
        // requireOfferisValid
        require(offer.nftContractAddress != address(0), "00004");
        _requireOfferNotExpired(offer);
        Loan storage loan = _getLoan(offer.nftContractAddress, offer.nftId);
        // requireNoOpenLoan
        require(loan.lastUpdatedTimestamp == 0, "00006");

        // add transfer of down payment

        uint256 downPaymentAmount = (offer.reservePrice * MAX_BPS) /
            offer.downPaymentBps;

        _arrangeAssetFromBuyer(buyer, offer.asset, downPaymentAmount);

        // if a direct sale, transfer value from this contract to seller transfer funds directly.

        // add create loan

        _createLoan(
            loan,
            offer,
            seller,
            buyer,
            (offer.reservePrice - downPaymentAmount)
        );

        // we might need to provide this inside of an if statement, if external purchase
        // execute opreation on receiver contract
        require(
            IFlashPurchaseReceiver(receiver).executeOperation(
                offer.nftContractAddress,
                offer.nftId,
                msg.sender,
                data
            ),
            "00052"
        );

        // Transfer nft from receiver contract to this contract as collateral, revert on failure
        _transferNft(
            offer.nftContractAddress,
            offer.nftId,
            receiver,
            address(this)
        );

        emit LoanExecuted(
            offer.nftContractAddress,
            offer.nftId,
            receiver,
            loan
        );
    }

    function acceptBidAndExecuteFinancing(
        Offer memory offer,
        // do we need to provide the signature here?
        bytes memory signature,
        uint256 saleAmount,
        address receiver,
        address buyer,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        address seller = getOfferSigner(offer, signature);

        // require msg.sender is seller

        _require721Owner(offer.nftContractAddress, offer.nftId, seller);
        // is this check sitll needed?
        _requireOfferCreator(offer.creator, seller);
        _requireAvailableSignature(signature);
        _requireSignature65(signature);
        // is offer.creator still needed in the offer struct?
        _requireIsNotSanctioned(offer.creator);
        _requireIsNotSanctioned(buyer);
        _requireIsNotSanctioned(receiver);
        // requireOfferisValid
        // might want to use address(0) to mean ETH, could check another value in the offer struct
        require(offer.nftContractAddress != address(0), "00004");
        _requireOfferNotExpired(offer);
        Loan storage loan = _getLoan(offer.nftContractAddress, offer.nftId);
        // requireNoOpenLoan
        require(loan.lastUpdatedTimestamp == 0, "00006");

        // assume the transfer of down payment happened on a 3rd party marketplace

        uint256 downPaymentAmount = (saleAmount * MAX_BPS) /
            offer.downPaymentBps;

        // add create loan

        _createLoan(
            loan,
            offer,
            seller,
            buyer,
            (saleAmount - downPaymentAmount)
        );

        // we might need to provide this inside of an if statement, if external purchase
        // execute opreation on receiver contract
        require(
            IFlashPurchaseReceiver(receiver).executeOperation(
                offer.nftContractAddress,
                offer.nftId,
                msg.sender,
                data
            ),
            "00052"
        );

        // Transfer nft from receiver contract to this contract as collateral, revert on failure
        _transferNft(
            offer.nftContractAddress,
            offer.nftId,
            receiver,
            address(this)
        );

        emit LoanExecuted(
            offer.nftContractAddress,
            offer.nftId,
            receiver,
            loan
        );
    }

    function instantSell(
        address nftContractAddress,
        uint256 nftId,
        address receiver,
        bytes calldata data
    ) external whenNotPaused nonReentrant {}

    function listNftForSale(
        address nftContractAddress,
        uint256 nftId,
        uint256 listingPrice,
        uint256 listingStartTime,
        uint256 listingEndTime,
        uint256 salt
    ) external whenNotPaused nonReentrant returns (bytes32) {}

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

    function _constructOrder(
        address nftContractAddress,
        uint256 nftId,
        uint256 listingPrice,
        uint256 seaportFeeAmount,
        uint256 listingStartTime,
        uint256 listingEndTime,
        address asset,
        uint256 randomSalt
    ) internal view returns (ISeaport.Order[] memory order) {}

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
        // ILending(lendingContractAddress).transferNft(
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

    function auctionDebt() public {}

    function refinanceLoan() public {}

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
        loan.amount = uint128(amount);
        // TODO @captn: need to check this math. feels weird.
        loan.periodEndTimestamp = _currentTimestamp32() + payPeriodDuration;
        loan.loanBeginTimestamp = _currentTimestamp32();
        loan.downPaymentBps = offer.downPaymentBps;
        loan.payPeriodPrincipalBps = offer.payPeriodPrincipalBps;
        loan.payPeriodInterestRateBps = offer.payPeriodInterestRateBps;
        loan.payPeriodDuration = offer.payPeriodDuration;
        loan.gracePeriodDuration = offer.gracePeriodDuration;
        loan.numLatePaymentTolerance = offer.numLatePaymentTolerance;
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

    function _arrangeAssetFromBuyer(
        address buyer,
        address offerAsset,
        uint256 downPaymentAmount
    ) internal {
        if (offerAsset == address(0)) {
            require(msg.value >= downPaymentAmount, "00047");
            if (msg.value > downPaymentAmount) {
                payable(buyer).sendValue(msg.value - downPaymentAmount);
            }
        } else {
            IERC20Upgradeable asset = IERC20Upgradeable(offerAsset);
            asset.safeTransferFrom(buyer, address(this), downPaymentAmount);
        }
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
        require(loan.amount != 0, "00007");
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
