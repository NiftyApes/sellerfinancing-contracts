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

    function buyWithFinancing(
        Offer memory offer,
        bytes memory signature,
        // TODO @captn: simply providing this here doesnt feel quite right....
        // perhaps we provide a minimum sale amount in the offer
        uint256 saleAmount,
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
        // might want to use address(0) to mean ETH, could check another value in the offer struct
        require(offer.asset != address(0), "00004");
        _requireOfferNotExpired(offer);
        Loan storage loan = _getLoan(offer.nftContractAddress, offer.nftId);
        // requireNoOpenLoan
        require(loan.lastUpdatedTimestamp == 0, "00006");

        // add transfer of down payment

        uint256 downPaymentAmount = (saleAmount * MAX_BPS) /
            offer.downPaymentBps;

        _arrangeAssetFromBuyer(buyer, offer.asset, downPaymentAmount);

        // if a direct sale, transfer value from this contract to seller transfer funds directly.

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
    ) external whenNotPaused nonReentrant {
        // address nftOwner = _requireNftOwner(nftContractAddress, nftId);
        // _requireIsNotSanctioned(msg.sender);
        // _requireIsNotSanctioned(nftOwner);
        // Loan memory loan = ILending(lendingContractAddress)
        //     .getLoan(nftContractAddress, nftId);
        // // transfer NFT
        // ILending(lendingContractAddress).transferNft(
        //     nftContractAddress,
        //     nftId,
        //     receiver
        // );
        // address loanAsset;
        // if (loan.asset != ETH_ADDRESS) {
        //     loanAsset = loan.asset;
        // }
        // uint256 totalLoanPaymentAmount = _calculateTotalLoanPaymentAmount(
        //     loan,
        //     nftContractAddress,
        //     nftId
        // );
        // uint256 assetBalanceBefore = _getAssetBalance(loan.asset);
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
        // uint256 assetBalanceAfter = _getAssetBalance(loan.asset);
        // // Check assets amount recieved is equal to total loan amount required to close the loan
        // _requireCorrectFundsSent(
        //     assetBalanceAfter - assetBalanceBefore,
        //     totalLoanPaymentAmount
        // );
        // if (loan.asset == ETH_ADDRESS) {
        //     ILending(lendingContractAddress).repayLoanForAccountInternal{
        //         value: totalLoanPaymentAmount
        //     }(nftContractAddress, nftId, loan.loanBeginTimestamp);
        // } else {
        //     IERC20Upgradeable assetToken = IERC20Upgradeable(loan.asset);
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
        //         loan.loanBeginTimestamp
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
        // Loan memory loan = ILending(lendingContractAddress)
        //     .getLoan(nftContractAddress, nftId);
        // uint256 seaportFeeAmount = listingPrice - (listingPrice * 39) / 40;
        // // validate inputs and its price wrt listingEndTime
        // _requireNftOwner(loan);
        // _requireIsNotSanctioned(msg.sender);
        // _requireOpenLoan(loan);
        // _requireListingValueGreaterThanLoanRepaymentAmountUntilListingExpiry(
        //     loan,
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
        //     loan.asset,
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
        // emit ListedOnSeaport(nftContractAddress, nftId, orderHash, loan);
        // return orderHash;
    }

    function validateSaleAndWithdraw(
        address nftContractAddress,
        uint256 nftId,
        bytes32 orderHash
    ) external whenNotPaused nonReentrant {
        // Loan memory loan = ILending(lendingContractAddress)
        //     .getLoan(nftContractAddress, nftId);
        // SeaportListing memory listing = _requireValidOrderHash(
        //     nftContractAddress,
        //     nftId,
        //     orderHash
        // );
        // _requireLenderOrNftOwner(loan);
        // _requireIsNotSanctioned(msg.sender);
        // _requireOpenLoan(loan);
        // // validate order status
        // (bool valid, bool cancelled, uint256 filled, ) = ISeaport(
        //     seaportContractAddress
        // ).getOrderStatus(orderHash);
        // require(valid, "00059");
        // require(!cancelled, "00062");
        // require(filled == 1, "00063");
        // // close the loan and transfer remaining amount to the borrower
        // uint256 totalLoanPaymentAmount = _calculateTotalLoanPaymentAmountAtTimestamp(
        //         loan,
        //         block.timestamp
        //     );
        // if (loan.asset == ETH_ADDRESS) {
        //     // settle the loan
        //     ILending(lendingContractAddress).repayLoanForAccountInternal{
        //         value: totalLoanPaymentAmount
        //     }(nftContractAddress, nftId, loan.loanBeginTimestamp);
        //     // transfer the remaining to the borrower
        //     payable(loan.nftOwner).sendValue(
        //         listing.listingValue - totalLoanPaymentAmount
        //     );
        // } else {
        //     // settle the loan
        //     IERC20Upgradeable assetToken = IERC20Upgradeable(loan.asset);
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
        //         loan.loanBeginTimestamp
        //     );
        //     // transfer the remaining to the borrower
        //     IERC20Upgradeable(loan.asset).safeTransfer(
        //         loan.nftOwner,
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
        // Loan memory loan = ILending(lendingContractAddress)
        //     .getLoan(nftContractAddress, nftId);
        // // validate inputs
        // _requireNftOwner(loan);
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
        //     loan
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

    function makePayment(
        address nftContractAddress,
        uint256 nftId,
        uint256 amount
    ) external payable whenNotPaused nonReentrant {
        Loan memory loan = _getLoan(nftContractAddress, nftId);
        address nftOwner = loan.buyer;
        // _repayLoanAmount(nftContractAddress, nftId, true, 0, true);
        _transferNft(nftContractAddress, nftId, address(this), nftOwner);
    }

    function _makePayment(
        address nftContractAddress,
        uint256 nftId,
        uint256 paymentAmount
    ) public {
        Loan storage loan = _getLoan(nftContractAddress, nftId);
        _requireIsNotSanctioned(loan.buyer);
        _requireIsNotSanctioned(msg.sender);
        _requireOpenLoan(loan);

        // check the currentPayPeriodEndTimestamp
        // if late increment latePayment counter
        // increment the currentPayPeriodBegin and End Timestamps equal to the payPeriodDuration
        // calculate the % of principal and interest that must be paid to the seller
        // calculate % interest to be paid to protocol
        // check if payment decrements principal to 0
        // pay out to seller and protocol
        // if principal == 0 transfer nft and end loan
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
        loan.loanEndTimestamp =
            _currentTimestamp32() +
            uint32(
                (offer.payPeriodDuration *
                    (amount /
                        ((amount * MAX_BPS) / offer.payPeriodPrincipalBps)))
            );
        loan.loanBeginTimestamp = _currentTimestamp32();
        loan.lastUpdatedTimestamp = _currentTimestamp32();
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
