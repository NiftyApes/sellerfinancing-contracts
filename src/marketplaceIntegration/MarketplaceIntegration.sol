//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/security/Pausable.sol";
import "@openzeppelin-norm/contracts/utils/Address.sol";
import "@openzeppelin-norm/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin-norm/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../interfaces/niftyapes/sellerFinancing/ISellerFinancing.sol";
import "../interfaces/niftyapes/INiftyApesStructs.sol";
import "../interfaces/sanctions/SanctionsList.sol";


/// @title MarketplaceIntegration
/// @custom:version 1.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)

contract MarketplaceIntegration is Ownable, Pausable, ERC721Holder {
    using Address for address payable;

    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address private constant SANCTIONS_CONTRACT = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @notice The base value for fees in the protocol.
    uint256 private constant BASE_BPS = 10_000;

    /// @dev The status of sanctions checks
    bool internal _sanctionsPause;

    uint256 public marketplaceFeeBps;

    address payable public marketplaceFeeRecipient;

    address public sellerFinancingContractAddress;

    error ZeroAddress();

    error InsufficientMsgValue(uint256 given, uint256 expected);

    error SanctionedAddress(address account);

    error InvalidInputLength();

    error BuyWithSellerFinancingCallRevertedAt(uint256 index);

    error InstantSellCallRevertedAt(uint256 index);

    error BuyerTicketTransferRevertedAt(uint256 index, address from, address to);

    constructor(
        address _sellerFinancingContractAddress,
        address _marketplaceFeeRecipient,
        uint256 _marketplaceFeeBps
    ) {
        _requireNonZeroAddress(_sellerFinancingContractAddress);
        _requireNonZeroAddress(_marketplaceFeeRecipient);

        sellerFinancingContractAddress = _sellerFinancingContractAddress;
        marketplaceFeeRecipient = payable(_marketplaceFeeRecipient);
        marketplaceFeeBps = _marketplaceFeeBps;
    }

    /// @param newSellerFinancingContractAddress New address for SellerFinancing contract
    function updateSellerFinancingContractAddress(
        address newSellerFinancingContractAddress
    ) external onlyOwner {
        _requireNonZeroAddress(newSellerFinancingContractAddress);
        sellerFinancingContractAddress = newSellerFinancingContractAddress;
    }

    /// @param newMarketplaceFeeRecipient New address for MarketplaceFeeRecipient
    function updateMarketplaceFeeRecipient(address newMarketplaceFeeRecipient) external onlyOwner {
        _requireNonZeroAddress(newMarketplaceFeeRecipient);
        marketplaceFeeRecipient = payable(newMarketplaceFeeRecipient);
    }

    /// @param newMarketplaceFeeBps New value for marketplaceFeeBps
    function updateMarketplaceFeeBps(uint256 newMarketplaceFeeBps) external onlyOwner {
        marketplaceFeeBps = newMarketplaceFeeBps;
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

    /// @notice Start a loan as buyer using a signed offer.
    /// @param offer The details of the financing offer
    /// @param signature Signature from the offer creator
    /// @param buyer The address of the buyer
    /// @param nftId The nftId of the nft the buyer intends to buy
    function buyWithSellerFinancing(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 nftId
    ) external payable whenNotPaused {
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        // calculate marketplace fee
        uint256 marketplaceFeeAmount = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * marketplaceFeeBps) / BASE_BPS;

        if (msg.value < offer.terms.downPaymentAmount + marketplaceFeeAmount) {
            revert InsufficientMsgValue(msg.value, offer.terms.downPaymentAmount + marketplaceFeeAmount);
        }

        // send marketplace fee to marketplace fee recipient
        marketplaceFeeRecipient.sendValue(marketplaceFeeAmount);

        // execute buyWithSellerFinancing
        ISellerFinancing(sellerFinancingContractAddress).buyWithSellerFinancing{
            value: msg.value - marketplaceFeeAmount
        }(offer, signature, buyer, nftId);
    }

    /// @notice Execute loan offers in batch for buyer
    /// @param offers The list of the offers to execute
    /// @param signatures The list of corresponding signatures from the offer creators
    /// @param buyer The address of the buyer
    /// @param nftIds The nftIds of the nfts the buyer intends to buy
    /// @param partialExecution If set to true, will continue to attempt transaction executions regardless
    ///        if previous transactions have failed or had insufficient value available
    function buyWithSellerFinancingBatch(
        INiftyApesStructs.Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata nftIds,
        bool partialExecution
    ) external payable whenNotPaused {
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        uint256 offersLength = offers.length;

        // requireLengthOfAllInputArraysAreEqual
        if (offersLength != signatures.length || offersLength != nftIds.length) {
            revert InvalidInputLength();
        }

        uint256 marketplaceFeeAccumulated;
        uint256 valueConsumed;

        // loop through list of offers to execute
        for (uint256 i; i < offersLength; ++i) {
            // instantiate ith offer
            INiftyApesStructs.Offer memory offer = offers[i];

            // calculate marketplace fee for ith offer
            uint256 marketplaceFeeAmount = ((offer.terms.principalAmount + offer.terms.downPaymentAmount) * marketplaceFeeBps) / BASE_BPS;

            // if remaining value is not sufficient to execute ith offer
            if (msg.value - valueConsumed < offer.terms.downPaymentAmount + marketplaceFeeAmount) {
                // if partial execution is allowed then move to next offer
                if (partialExecution) {
                    continue;
                }
                // else revert
                else {
                    revert InsufficientMsgValue(
                        msg.value,
                        valueConsumed + offer.terms.downPaymentAmount + marketplaceFeeAmount
                    );
                }
            }
            // try executing current offer,
            try
                ISellerFinancing(sellerFinancingContractAddress).buyWithSellerFinancing{
                    value: offer.terms.downPaymentAmount
                }(offer, signatures[i], buyer, nftIds[i])
            {
                // if successful
                // increment marketplaceFeeAccumulated
                marketplaceFeeAccumulated += marketplaceFeeAmount;
                // increment valueConsumed
                valueConsumed += offer.terms.downPaymentAmount + marketplaceFeeAmount;
            } catch {
                // if failed
                // if partial execution is not allowed, revert
                if (!partialExecution) {
                    revert BuyWithSellerFinancingCallRevertedAt(i);
                }
            }
        }

        // send accumulated marketplace fee to marketplace fee recipient
        marketplaceFeeRecipient.sendValue(marketplaceFeeAccumulated);

        // send any unused value back to msg.sender
        if (msg.value - valueConsumed > 0) {
            payable(msg.sender).sendValue(msg.value - valueConsumed);
        }
    }
    
    /// @notice Execute instantSell on all the NFTs in the provided input
    /// @param nftContractAddresses The list of all the nft contract addresses
    /// @param nftIds The list of all the nft IDs
    /// @param minProfitAmounts List of minProfitAmount for each `instantSell` call
    /// @param data The list of data to be passed to each `instantSell` call
    /// @param partialExecution If set to true, will continue to attempt next request in the loop
    ///        when one `instantSell` or transfer ticket call fails
    function instantSellBatch(
        address[] memory nftContractAddresses,
        uint256[] memory nftIds,
        uint256[] memory minProfitAmounts,
        bytes[] calldata data,
        bool partialExecution
    ) external whenNotPaused {
        _requireIsNotSanctioned(msg.sender);

        uint256 executionCount = nftContractAddresses.length;
        // requireLengthOfAllInputArraysAreEqual
        if(nftIds.length != executionCount || minProfitAmounts.length != executionCount || data.length != executionCount) {
            revert InvalidInputLength();
        }
        
        uint256 contractBalanceBefore = address(this).balance;
        for (uint256 i; i < executionCount; ++i) {
            // intantiate NFT details
            address nftContractAddress = nftContractAddresses[i];
            uint256 nftId = nftIds[i];
            // fetech active loan details
            INiftyApesStructs.Loan memory loan = ISellerFinancing(sellerFinancingContractAddress).getLoan(nftContractAddress, nftId);
            // transfer buyerNft from caller to this contract.
            // this call also ensures that loan exists and caller is the current buyer
            try IERC721(sellerFinancingContractAddress).safeTransferFrom(msg.sender, address(this), loan.borrowerNftId) {
                // call instantSell to close the loan
                try ISellerFinancing(sellerFinancingContractAddress).instantSell(nftContractAddress, nftId, minProfitAmounts[i], data[i]) {} 
                catch {
                    if (!partialExecution) {
                        revert InstantSellCallRevertedAt(i);
                    } else {
                        IERC721(sellerFinancingContractAddress).safeTransferFrom(address(this), msg.sender, loan.borrowerNftId);
                    }
                }
            } catch {
                if (!partialExecution) {
                    revert BuyerTicketTransferRevertedAt(i, msg.sender, address(this));
                }
            }
            
        }
        // accumulate value received
        uint256 valueReceived = address(this).balance - contractBalanceBefore;
        // send all the amount received to the caller
        if( valueReceived > 0) {
            payable(msg.sender).sendValue(valueReceived);
        }
    }

    function _requireNonZeroAddress(address given) internal pure {
        if (given == address(0)) {
            revert ZeroAddress();
        }
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

    /// @notice This contract needs to accept ETH from `instantSell` calls
    receive() external payable {}
}
