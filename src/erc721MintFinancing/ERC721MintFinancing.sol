//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin-norm/contracts/utils/Counters.sol";
import "../interfaces/sellerFinancing/ISellerFinancing.sol";

/// @title ERC721MintFinancing
/// @custom:version 1.0
/// @author captnseagraves (captnseagraves.eth)

contract ERC721MintFinancing is ERC721, Ownable {
    using Counters for Counters.Counter;

    /// @dev Token ID Tracker
    Counters.Counter private _tokenIdTracker;

    // TODO Do we need to provide a mint limit as part of the contract? Should look at manifold contracts to see pattern.

    /// @dev The stored address for the seller financing contract
    address public sellerFinancingContractAddress;

    error ZeroAddress();

    error CannotMint0();

    error CollectionOfferLimitReached();

    error InsufficientMsgValue(uint256 given, uint256 expected);

    error InvalidNftContractAddress(address given, address expected);

    error InvalidSigner(address signer, address expected);

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
    /// @param count The number of NFTs to mint
    /// @dev   The count must be greater than 0.
    ///        If the count increments the collectionOfferLimit counter up to the collectionOffer limit
    ///        all NFTs will be minted up to the limit.
    function mintWithFinancing(
        ISellerFinancing.Offer memory offer,
        bytes calldata signature,
        uint256 count
    ) external payable returns (uint256[] memory tokenIds) {
        address signer = ISellerFinancing(sellerFinancingContractAddress).getOfferSigner(
            offer,
            signature
        );

        uint64 collectionOfferLimitCount = ISellerFinancing(sellerFinancingContractAddress)
            .getCollectionOfferCount(signature);

        tokenIds = new uint256[](count);
        uint256 firstTokenId = _tokenIdTracker.current() + 1;
        uint256 maxCount = count;

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

        // loop through number of count
        for (uint i; i < count; ) {
            // if collectionOfferLimit not reached
            if (collectionOfferLimitCount < offer.collectionOfferLimit) {
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

                // increment loop
                unchecked {
                    ++i;
                }
            }
            // else if collectionOfferLimit reached
            else {
                // exit loop without revert so user doesnt have to enter perfect count
                count = maxCount;
            }
        }
    }

    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }
}
