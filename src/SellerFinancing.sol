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
    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @dev A mapping for storing the seaport listing with its hash as the key
    mapping(bytes32 => SeaportListing) private _orderHashToListing;

    /// @dev A mapping to mark a signature as used.
    ///      The mapping allows users to withdraw offers that they made by signature.
    mapping(bytes => bool) private _cancelledOrFinalized;

    /// @dev The status of sanctions checks. Can be set to false if oracle becomes malicious.
    bool internal _sanctionsPause;

    // Mapping owner to nftContractAddress to token count
    mapping(address => mapping(address => uint256)) private _balances;

    // Mapping from owner to nftContractAddress to list of owned token IDs
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        private _ownedTokens;

    // Mapping from nftContractAddress to token ID to index of the owner tokens list
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensIndex;

    /// @inheritdoc ISellOnSeaport
    address public seaportContractAddress;

    /// @inheritdoc ISellOnSeaport
    address public seaportZone;

    /// @inheritdoc ISellOnSeaport
    address public seaportFeeRecepient;

    /// @inheritdoc ISellOnSeaport
    bytes32 public seaportZoneHash;

    /// @inheritdoc ISellOnSeaport
    bytes32 public seaportConduitKey;

    /// @inheritdoc ISellOnSeaport
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

    /// @inheritdoc IOffersAdmin
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc IOffersAdmin
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc IOffers
    function getOfferHash(Offer memory offer) public view returns (bytes32) {
        // return
        //     _hashTypedDataV4(
        //         keccak256(
        //             abi.encode(
        //                 0x428a8e8c29d93e1e11aecebd37fa09e4f7c542a1302c7ac497bf5f49662103a5,
        //                 keccak256(
        //                     abi.encode(
        //                         offer.creator,
        //                         offer.duration,
        //                         offer.expiration,
        //                         offer.fixedTerms,
        //                         offer.floorTerm,
        //                         offer.lenderOffer,
        //                         offer.nftContractAddress,
        //                         offer.nftId,
        //                         offer.asset,
        //                         offer.amount,
        //                         offer.interestRatePerSecond,
        //                         offer.floorTermLimit
        //                     )
        //                 )
        //             )
        //         )
        //     );
    }

    /// @inheritdoc IOffers
    function getOfferSigner(Offer memory offer, bytes memory signature)
        public
        view
        override
        returns (address)
    {
        return ECDSABridge.recover(getOfferHash(offer), signature);
    }

    /// @inheritdoc IOffers
    function getOfferSignatureStatus(bytes memory signature)
        external
        view
        returns (bool)
    {
        return _cancelledOrFinalized[signature];
    }

    /// @inheritdoc IOffers
    function withdrawOfferSignature(Offer memory offer, bytes memory signature)
        external
        whenNotPaused
    {
        // requireAvailableSignature(signature);
        // requireSignature65(signature);
        // address signer = getOfferSigner(offer, signature);
        // _requireSigner(signer, msg.sender);
        // _requireOfferCreator(offer.creator, msg.sender);
        // _markSignatureUsed(offer, signature);
    }

    function buyWithFinancing(
        Offer memory offer,
        bytes memory signature,
        uint256 nftId,
        address receiver,
        address buyer,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // address lender = getOfferSigner(offer, signature);
        // // add require signer is 721 owner
        // _requireOfferCreator(offer, lender);
        // requireAvailableSignature(signature);
        // requireSignature65(signature);
        // _requireIsNotSanctioned(offer.creator);
        // _requireIsNotSanctioned(borrower);
        // _requireIsNotSanctioned(receiver);
        // // requireOfferisValid
        // require(offer.asset != address(0), "00004");
        // _requireOfferNotExpired(offer);
        // _requireMinDurationForOffer(offer);
        // LoanAuction memory loanAuction = ILending(lendingContractAddress)
        //     .getLoanAuction(offer.nftContractAddress, nftId);
        // // requireNoOpenLoan
        // require(loanAuction.lastUpdatedTimestamp == 0, "00006");
        // // add transfer of doan payment
        // // add create loan
        // // execute opreation on receiver contract
        // require(
        //     IFlashPurchaseReceiver(receiver).executeOperation(
        //         offer.nftContractAddress,
        //         nftId,
        //         msg.sender,
        //         data
        //     ),
        //     "00052"
        // );
        // // Transfer nft from receiver contract to this contract as collateral, revert on failure
        // _transferNft(
        //     offer.nftContractAddress,
        //     nftId,
        //     receiver,
        //     lendingContractAddress
        // );
        // emit LoanExecutedForPurchase(
        //     offer.nftContractAddress,
        //     nftId,
        //     receiver,
        //     loanAuction
        // );
    }

    function instantSell(
        address nftContractAddress,
        uint256 nftId,
        address receiver,
        bytes calldata data
    ) external whenNotPaused nonReentrant {
        // address nftOwner = _requireNftOwner(nftContractAddress, nftId);
        // _requireIsNotSanctioned(msg.sender);
        // _requireIsNotSanctioned(nftOwner);
        // LoanAuction memory loanAuction = ILending(lendingContractAddress)
        //     .getLoanAuction(nftContractAddress, nftId);
        // // transfer NFT
        // ILending(lendingContractAddress).transferNft(
        //     nftContractAddress,
        //     nftId,
        //     receiver
        // );
        // address loanAsset;
        // if (loanAuction.asset != ETH_ADDRESS) {
        //     loanAsset = loanAuction.asset;
        // }
        // uint256 totalLoanPaymentAmount = _calculateTotalLoanPaymentAmount(
        //     loanAuction,
        //     nftContractAddress,
        //     nftId
        // );
        // uint256 assetBalanceBefore = _getAssetBalance(loanAuction.asset);
        // _ethTransferable = true;
        // // execute firewalled external arbitrary functionality
        // // function must send correct funds required to close the loan
        // require(
        //     IFlashSellReceiver(receiver).executeOperation(
        //         nftContractAddress,
        //         nftId,
        //         loanAsset,
        //         totalLoanPaymentAmount,
        //         msg.sender,
        //         data
        //     ),
        //     "00052"
        // );
        // _ethTransferable = false;
        // uint256 assetBalanceAfter = _getAssetBalance(loanAuction.asset);
        // // Check assets amount recieved is equal to total loan amount required to close the loan
        // _requireCorrectFundsSent(
        //     assetBalanceAfter - assetBalanceBefore,
        //     totalLoanPaymentAmount
        // );
        // if (loanAuction.asset == ETH_ADDRESS) {
        //     ILending(lendingContractAddress).repayLoanForAccountInternal{
        //         value: totalLoanPaymentAmount
        //     }(nftContractAddress, nftId, loanAuction.loanBeginTimestamp);
        // } else {
        //     IERC20Upgradeable assetToken = IERC20Upgradeable(loanAuction.asset);
        //     uint256 allowance = assetToken.allowance(
        //         address(this),
        //         liquidityContractAddress
        //     );
        //     if (allowance > 0) {
        //         assetToken.safeDecreaseAllowance(
        //             liquidityContractAddress,
        //             allowance
        //         );
        //     }
        //     assetToken.safeIncreaseAllowance(
        //         liquidityContractAddress,
        //         totalLoanPaymentAmount
        //     );
        //     ILending(lendingContractAddress).repayLoanForAccountInternal(
        //         nftContractAddress,
        //         nftId,
        //         loanAuction.loanBeginTimestamp
        //     );
        // }
        // // emit event
        // emit FlashSell(nftContractAddress, nftId, receiver);
    }

    function listNftForSale(
        address nftContractAddress,
        uint256 nftId,
        uint256 listingPrice,
        uint256 listingStartTime,
        uint256 listingEndTime,
        uint256 salt
    ) external whenNotPaused nonReentrant returns (bytes32) {
        // LoanAuction memory loanAuction = ILending(lendingContractAddress)
        //     .getLoanAuction(nftContractAddress, nftId);
        // uint256 seaportFeeAmount = listingPrice - (listingPrice * 39) / 40;
        // // validate inputs and its price wrt listingEndTime
        // _requireNftOwner(loanAuction);
        // _requireIsNotSanctioned(msg.sender);
        // _requireOpenLoan(loanAuction);
        // _requireListingValueGreaterThanLoanRepaymentAmountUntilListingExpiry(
        //     loanAuction,
        //     listingPrice,
        //     seaportFeeAmount,
        //     listingEndTime
        // );
        // // construct Seaport Order
        // ISeaport.Order[] memory order = _constructOrder(
        //     nftContractAddress,
        //     nftId,
        //     listingPrice,
        //     seaportFeeAmount,
        //     listingStartTime,
        //     listingEndTime,
        //     loanAuction.asset,
        //     salt
        // );
        // // approve the NFT for Seaport address
        // ILending(lendingContractAddress).approveNft(
        //     nftContractAddress,
        //     nftId,
        //     seaportConduit
        // );
        // // call lending contract to validate listing to Seaport
        // ILending(lendingContractAddress).validateSeaportOrderSellOnSeaport(
        //     seaportContractAddress,
        //     order
        // );
        // // get orderHash by calling ISeaport.getOrderHash()
        // bytes32 orderHash = _getOrderHash(order[0]);
        // // validate order status by calling ISeaport.getOrderStatus(orderHash)
        // (bool validated, , , ) = ISeaport(seaportContractAddress)
        //     .getOrderStatus(orderHash);
        // require(validated, "00059");
        // // store the listing with orderHash
        // _orderHashToListing[orderHash] = SeaportListing(
        //     nftContractAddress,
        //     nftId,
        //     listingPrice - seaportFeeAmount
        // );
        // // emit orderHash with it's listing
        // emit ListedOnSeaport(nftContractAddress, nftId, orderHash, loanAuction);
        // return orderHash;
    }

    function validateSaleAndWithdraw(
        address nftContractAddress,
        uint256 nftId,
        bytes32 orderHash
    ) external whenNotPaused nonReentrant {
        // LoanAuction memory loanAuction = ILending(lendingContractAddress)
        //     .getLoanAuction(nftContractAddress, nftId);
        // SeaportListing memory listing = _requireValidOrderHash(
        //     nftContractAddress,
        //     nftId,
        //     orderHash
        // );
        // _requireLenderOrNftOwner(loanAuction);
        // _requireIsNotSanctioned(msg.sender);
        // _requireOpenLoan(loanAuction);
        // // validate order status
        // (bool valid, bool cancelled, uint256 filled, ) = ISeaport(
        //     seaportContractAddress
        // ).getOrderStatus(orderHash);
        // require(valid, "00059");
        // require(!cancelled, "00062");
        // require(filled == 1, "00063");
        // // close the loan and transfer remaining amount to the borrower
        // uint256 totalLoanPaymentAmount = _calculateTotalLoanPaymentAmountAtTimestamp(
        //         loanAuction,
        //         block.timestamp
        //     );
        // if (loanAuction.asset == ETH_ADDRESS) {
        //     // settle the loan
        //     ILending(lendingContractAddress).repayLoanForAccountInternal{
        //         value: totalLoanPaymentAmount
        //     }(nftContractAddress, nftId, loanAuction.loanBeginTimestamp);
        //     // transfer the remaining to the borrower
        //     payable(loanAuction.nftOwner).sendValue(
        //         listing.listingValue - totalLoanPaymentAmount
        //     );
        // } else {
        //     // settle the loan
        //     IERC20Upgradeable assetToken = IERC20Upgradeable(loanAuction.asset);
        //     uint256 allowance = assetToken.allowance(
        //         address(this),
        //         liquidityContractAddress
        //     );
        //     if (allowance > 0) {
        //         assetToken.safeDecreaseAllowance(
        //             liquidityContractAddress,
        //             allowance
        //         );
        //     }
        //     assetToken.safeIncreaseAllowance(
        //         liquidityContractAddress,
        //         totalLoanPaymentAmount
        //     );
        //     ILending(lendingContractAddress).repayLoanForAccountInternal(
        //         nftContractAddress,
        //         nftId,
        //         loanAuction.loanBeginTimestamp
        //     );
        //     // transfer the remaining to the borrower
        //     IERC20Upgradeable(loanAuction.asset).safeTransfer(
        //         loanAuction.nftOwner,
        //         listing.listingValue - totalLoanPaymentAmount
        //     );
        // }
    }

    function cancelNftListing(ISeaport.OrderComponents memory orderComponents)
        external
        whenNotPaused
        nonReentrant
    {
        // bytes32 orderHash = ISeaport(seaportContractAddress).getOrderHash(
        //     orderComponents
        // );
        // address nftContractAddress = orderComponents.offer[0].token;
        // uint256 nftId = orderComponents.offer[0].identifierOrCriteria;
        // LoanAuction memory loanAuction = ILending(lendingContractAddress)
        //     .getLoanAuction(nftContractAddress, nftId);
        // // validate inputs
        // _requireNftOwner(loanAuction);
        // _requireValidOrderHash(nftContractAddress, nftId, orderHash);
        // _requireIsNotSanctioned(msg.sender);
        // // validate order status
        // (bool valid, bool cancelled, uint256 filled, ) = ISeaport(
        //     seaportContractAddress
        // ).getOrderStatus(orderHash);
        // require(valid, "00059");
        // require(!cancelled, "00062");
        // require(filled == 0, "00063");
        // ISeaport.OrderComponents[]
        //     memory orderComponentsList = new ISeaport.OrderComponents[](1);
        // orderComponentsList[0] = orderComponents;
        // require(
        //     ILending(lendingContractAddress).cancelOrderSellOnSeaport(
        //         seaportContractAddress,
        //         orderComponentsList
        //     ),
        //     "00065"
        // );
        // // emit orderHash with it's listing
        // emit ListingCancelledSeaport(
        //     nftContractAddress,
        //     nftId,
        //     orderHash,
        //     loanAuction
        // );
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
        // ISeaport.ItemType considerationItemType = (
        //     asset == ETH_ADDRESS
        //         ? ISeaport.ItemType.NATIVE
        //         : ISeaport.ItemType.ERC20
        // );
        // address considerationToken = (
        //     asset == ETH_ADDRESS ? address(0) : asset
        // );
        // order = new ISeaport.Order[](1);
        // order[0] = ISeaport.Order({
        //     parameters: ISeaport.OrderParameters({
        //         offerer: lendingContractAddress,
        //         zone: seaportZone,
        //         offer: new ISeaport.OfferItem[](1),
        //         consideration: new ISeaport.ConsiderationItem[](2),
        //         orderType: ISeaport.OrderType.FULL_OPEN,
        //         startTime: listingStartTime,
        //         endTime: listingEndTime,
        //         zoneHash: seaportZoneHash,
        //         salt: randomSalt,
        //         conduitKey: seaportConduitKey,
        //         totalOriginalConsiderationItems: 2
        //     }),
        //     signature: bytes("")
        // });
        // order[0].parameters.offer[0] = ISeaport.OfferItem({
        //     itemType: ISeaport.ItemType.ERC721,
        //     token: nftContractAddress,
        //     identifierOrCriteria: nftId,
        //     startAmount: 1,
        //     endAmount: 1
        // });
        // order[0].parameters.consideration[0] = ISeaport.ConsiderationItem({
        //     itemType: considerationItemType,
        //     token: considerationToken,
        //     identifierOrCriteria: 0,
        //     startAmount: listingPrice - seaportFeeAmount,
        //     endAmount: listingPrice - seaportFeeAmount,
        //     recipient: payable(address(this))
        // });
        // order[0].parameters.consideration[1] = ISeaport.ConsiderationItem({
        //     itemType: considerationItemType,
        //     token: considerationToken,
        //     identifierOrCriteria: 0,
        //     startAmount: seaportFeeAmount,
        //     endAmount: seaportFeeAmount,
        //     recipient: payable(seaportFeeRecepient)
        // });
    }

    function repayLoan(address nftContractAddress, uint256 nftId)
        external
        payable
        override
        whenNotPaused
        nonReentrant
    {
        // LoanAuction memory loanAuction = _getLoanAuctionInternal(
        //     nftContractAddress,
        //     nftId
        // );
        // address nftOwner = loanAuction.nftOwner;
        // _repayLoanAmount(nftContractAddress, nftId, true, 0, true);
        // _transferNft(nftContractAddress, nftId, address(this), nftOwner);
    }

    /// @inheritdoc ILending
    function repayLoanForAccount(
        address nftContractAddress,
        uint256 nftId,
        uint32 expectedLoanBeginTimestamp
    ) external payable override whenNotPaused nonReentrant {
        // LoanAuction memory loanAuction = _getLoanAuctionInternal(
        //     nftContractAddress,
        //     nftId
        // );
        // // requireExpectedLoanIsActive
        // require(
        //     loanAuction.loanBeginTimestamp == expectedLoanBeginTimestamp,
        //     "00027"
        // );
        // _requireIsNotSanctioned(msg.sender);
        // address nftOwner = loanAuction.nftOwner;
        // _repayLoanAmount(nftContractAddress, nftId, true, 0, false);
        // _transferNft(nftContractAddress, nftId, address(this), nftOwner);
    }

    function seizeAsset(address nftContractAddress, uint256 nftId)
        external
        whenNotPaused
        nonReentrant
    {
        // LoanAuction storage loanAuction = _getLoanAuctionInternal(
        //     nftContractAddress,
        //     nftId
        // );
        // ILiquidity(liquidityContractAddress).getCAsset(loanAuction.asset); // Ensure asset mapping exists
        // _requireIsNotSanctioned(loanAuction.lender);
        // _requireOpenLoan(loanAuction);
        // // requireLoanExpired
        // require(_currentTimestamp32() >= loanAuction.loanEndTimestamp, "00008");
        // address currentLender = loanAuction.lender;
        // address nftOwner = loanAuction.nftOwner;
        // emit AssetSeized(nftContractAddress, nftId, loanAuction);
        // delete _loanAuctions[nftContractAddress][nftId];
        // _transferNft(nftContractAddress, nftId, address(this), currentLender);
        // _removeTokenFromOwnerEnumeration(nftOwner, nftContractAddress, nftId);
    }

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

    function auctionDebt() {
        _;
    }

    function refinanceLoan() {
        _;
    }

    function balanceOf(address owner, address nftContractAddress)
        public
        view
        override
        returns (uint256)
    {
        require(owner != address(0), "00035");
        return _balances[owner][nftContractAddress];
    }

    function tokenOfOwnerByIndex(
        address owner,
        address nftContractAddress,
        uint256 index
    ) public view override returns (uint256) {
        require(index < balanceOf(owner, nftContractAddress), "00069");
        return _ownedTokens[owner][nftContractAddress][index];
    }

    /// @inheritdoc IOffers
    function requireAvailableSignature(bytes memory signature) public view {
        require(!_cancelledOrFinalized[signature], "00032");
    }

    /// @inheritdoc IOffers
    function requireSignature65(bytes memory signature) public pure {
        require(signature.length == 65, "00003");
    }

    /// @inheritdoc IOffers
    function requireMinimumDuration(Offer memory offer) public pure {
        require(offer.duration >= 1 days, "00011");
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

    function renounceOwnership() public override onlyOwner {}
}
