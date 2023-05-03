//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-norm/contracts/utils/math/Math.sol";
import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin-norm/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin-norm/contracts/utils/Counters.sol";
import "../interfaces/sellerFinancing/ISellerFinancing.sol";

/// @title ERC721MintFinancing
/// @custom:version 1.0
/// @author captnseagraves (captnseagraves.eth)

// TODO add nonreentrant

contract ERC721MintFinancing is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    /// @dev Token ID Tracker
    Counters.Counter private _tokenIdTracker;

    /// @dev The stored address for the seller financing contract
    address public sellerFinancingContractAddress;

    error ZeroAddress();

    error CannotMint0();

    error CollectionOfferLimitReached();

    error InsufficientMsgValue(uint256 given, uint256 expected);

    error InvalidNftContractAddress(address given, address expected);

    error InvalidSigner(address signer, address expected);

    error ReturnValueFailed();

    constructor(
        string memory _name,
        string memory _symbol,
        address _sellerFinancingContractAddress
    ) ERC721(_name, _symbol) {
        _requireNonZeroAddress(_sellerFinancingContractAddress);
        sellerFinancingContractAddress = _sellerFinancingContractAddress;
    }

    /// @param newSellerFinancingContractAddress New address for SellerFinancing contract
    function updateSellerFinancingContractAddress(
        address newSellerFinancingContractAddress
    ) external onlyOwner {
        _requireNonZeroAddress(newSellerFinancingContractAddress);
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
    }

    /// @notice Mints an NFT with financing
    /// @dev The Mint Financing Offer must come from the owner of this contract
    /// @param offer The seller financing offer made by this contract owner
    /// @param signature The signed seller financing offer made by this contract owner,
    /// @param count The number of NFTs requested to mint
    /// @dev   The count must be greater than 0.
    ///        If the count increments the sellerfinancing.collectionOfferLimit counter up to the collectionOffer limit
    ///        all NFTs will be minted up to the limit and excess funds will be returned.
    ///        If the first NFT of a collection is minted with finance the collection tokenIds will begin at index 1
    function mintWithFinancing(
        ISellerFinancing.Offer memory offer,
        bytes calldata signature,
        uint256 count
    ) external payable nonReentrant returns (uint256[] memory tokenIds) {
        address signer = ISellerFinancing(sellerFinancingContractAddress).getOfferSigner(
            offer,
            signature
        );

        uint64 collectionOfferLimitCount = ISellerFinancing(sellerFinancingContractAddress)
            .getCollectionOfferCount(signature);

        tokenIds = new uint256[](count);
        uint256 firstTokenId = _tokenIdTracker.current() + 1;

        // requireSignerIsOwner
        if (signer != owner()) {
            revert InvalidSigner(signer, owner());
        }
        // requireValidNftContractAddress
        if (offer.nftContractAddress != address(this)) {
            revert InvalidNftContractAddress(offer.nftContractAddress, address(this));
        }
        // requireMsgValueGreaterThanOrEqualToOfferDownPaymentAmountTimesCount
        if (msg.value < (offer.downPaymentAmount * count)) {
            revert InsufficientMsgValue(msg.value, (offer.downPaymentAmount * count));
        }
        // requireCountIsNot0
        if (count == 0) {
            revert CannotMint0();
        }
        // requireCollectionOfferLimitNotReached
        if (collectionOfferLimitCount >= offer.collectionOfferLimit) {
            revert CollectionOfferLimitReached();
        }

        // calculate number of nfts to mint
        uint256 nftsToMint = Math.min(
            count,
            (offer.collectionOfferLimit - collectionOfferLimitCount)
        );

        // if there is a greater number of NFTs requested than available return value
        if (nftsToMint < count) {
            (bool success, ) = address(msg.sender).call{
                value: msg.value - (offer.downPaymentAmount * (count - nftsToMint))
            }("");
            // require ETH is successfully sent to msg.sender
            // we do not want ETH hanging in contract.
            if (!success) {
                revert ReturnValueFailed();
            }
        }

        for (uint i; i < nftsToMint; ++i) {
            // mint nft
            _safeMint(owner(), firstTokenId + i);
            // append new nftId to returned tokensIds
            tokenIds[i] = firstTokenId + i;
            // increment nftid tracker
            _tokenIdTracker.increment();

            // Execute loan
            ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing{
                value: (msg.value / count)
            }(offer, signature, msg.sender, firstTokenId + i);
        }
    }

    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }
}
