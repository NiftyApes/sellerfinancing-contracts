// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271Upgradeable.sol";
import "../interfaces/sanctions/SanctionsList.sol";
import "../externalExecuters/interfaces/IPurchaseExecuter.sol";
import "../externalExecuters/interfaces/ISaleExecuter.sol";
import "../interfaces/sellerFinancing/ISellerFinancing.sol";

contract SellerFinancingMaker is 
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721HolderUpgradeable,
    PausableUpgradeable,
    IERC1271Upgradeable
{
    using AddressUpgradeable for address payable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    address public sellerFinancingContractAddress;

    address public allowedOfferSigner;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting storage.
    uint256[500] private __gap;

    // --- Errors ---

    error InvalidOfferSigner();

    /// @notice The initializer for the marketplace integration contract.
    function initialize(
        address newSellerFinancingContractAddress,
        address newAllowedOfferSigner
    ) public initializer {
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
        allowedOfferSigner = newAllowedOfferSigner;

        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        ERC721HolderUpgradeable.__ERC721Holder_init();
    }

    function updateSellerFinancingContractAddress(
        address newSellerFinancingContractAddress
    ) external onlyOwner {
        require(
            address(newSellerFinancingContractAddress) != address(0),
            "00055"
        );
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
    }

    function updateAllowedOfferSigner(
        address newAllowedOfferSigner
    ) external onlyOwner {
        allowedOfferSigner = newAllowedOfferSigner;
    }

    /** @dev    See {IERC1271-isValidSignature}.
     *           returns empty bytes if `hash` provided is not equal to the hash of expected
     *           current valid offer struct.
     */
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) public view override returns (bytes4 magicValue) {
        if (
            ECDSAUpgradeable.recover(hash, signature) == allowedOfferSigner
        ) {
            magicValue = this.isValidSignature.selector;
        }
    }

    function withdraw(uint256 _amount) external onlyOwner nonReentrant {
        payable(owner()).sendValue(_amount);
    }

    function buyWithFinancing(
        ISellerFinancing.Offer calldata offer,
        bytes memory signature,
        address buyer,
        address purchaseExecuter,
        bytes calldata data
    ) external payable whenNotPaused nonReentrant {
        _requireIsNotSanctioned(offer.creator);
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);
        _requireValidSigner(ISellerFinancing(sellerFinancingContractAddress).getOfferSigner(offer, signature));

        // arrange asset amount from the buyer side for the purchase
        require(msg.value >= offer.downPaymentAmount, "Insufficient funds received for downPaymentAmount");
        if (msg.value > offer.downPaymentAmount) {
            payable(buyer).sendValue(msg.value - offer.downPaymentAmount);
        }

        // execute opreation on receiver contract and send funds for purchase
        require(IPurchaseExecuter(purchaseExecuter).executePurchase{value: offer.price}(
            offer.nftContractAddress,
            offer.nftId,
            data
        ), "Purchase was unsuccessful!");

        // Transfer nft from purchaseExecuter contract to this, revert on failure
        _transferNft(
            offer.nftContractAddress,
            offer.nftId,
            purchaseExecuter,
            address(this)
        );

        // approve the sellerFinancing contract for the purchased nft
        // validates that order and offer are for same NFT
        IERC721Upgradeable(offer.nftContractAddress).approve(
            sellerFinancingContractAddress,
            offer.nftId
        );

        ISellerFinancing(sellerFinancingContractAddress).buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            signature,
            buyer
        );
    }

    function _transferNft(
        address nftContractAddress,
        uint256 nftId,
        address from,
        address to
    ) internal {
        IERC721Upgradeable(nftContractAddress).safeTransferFrom(from, to, nftId);
    }

    function _requireIsNotSanctioned(address addressToCheck) internal view {
        if (!_sanctionsPause) {
            SanctionsList sanctionsList = SanctionsList(SANCTIONS_CONTRACT);
            bool isToSanctioned = sanctionsList.isSanctioned(addressToCheck);
            require(!isToSanctioned, "00017");
        }
    }

    function _requireValidSigner(address _offerSigner) internal view {
        if (_offerSigner != allowedOfferSigner) {
            revert InvalidOfferSigner();
        }
    }

    /// @notice This contract needs to accept ETH to acquire funds to purchase NFTs
    receive() external payable {
        // _checkOwner();
    }
}
