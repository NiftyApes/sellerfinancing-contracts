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

    /// @dev The stored address for the seller financing contract
    address public sellerFinancingContractAddress;

    error ZeroAddress();

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
    /// @param signature The signed seller financing offer made by this contract owner
    function mintWithFinancing(
        ISellerFinancing.Offer memory offer,
        bytes calldata signature
    ) external payable {
        address signer = ISellerFinancing(sellerFinancingContractAddress).getOfferSigner(
            offer,
            signature
        );

        // requireSignerIsOwner
        if (signer != owner()) {
            revert InvalidSigner(signer, owner());
        }
        // requireValidNftContractAddress
        if (offer.nftContractAddress != address(this)) {
            revert InvalidNftContractAddress(offer.nftContractAddress, address(this));
        }
        // requireMsgValueGreaterThanOrEqualToOfferDownPaymentAmount
        if (msg.value < offer.downPaymentAmount) {
            revert InsufficientMsgValue(msg.value, offer.downPaymentAmount);
        }

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _safeMint(owner(), _tokenIdTracker.current());
        _tokenIdTracker.increment();

        // Execute loan
        ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing{ value: msg.value }(
            offer,
            signature,
            msg.sender,
            _tokenIdTracker.current() - 1
        );
    }

    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
    }
}
