//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin-norm/contracts/access/Ownable.sol";
import "@openzeppelin-norm/contracts/security/Pausable.sol";
import "@openzeppelin-norm/contracts/utils/Address.sol";
import "@openzeppelin-norm/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin-norm/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../interfaces/niftyapes/INiftyApes.sol";
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
    /// @param tokenId The tokenId of the token the buyer intends to buy
    /// @param tokenAmount Amount of the specified token if ERC1155
    function buyWithSellerFinancing(
        INiftyApesStructs.Offer memory offer,
        bytes calldata signature,
        address buyer,
        uint256 tokenId,
        uint256 tokenAmount
    ) external payable whenNotPaused returns (uint256 loanId) {
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        // calculate marketplace fee
        uint256 marketplaceFeeAmount = ((offer.loanTerms.principalAmount +
            offer.loanTerms.downPaymentAmount) * marketplaceFeeBps) / BASE_BPS;

        if (msg.value < offer.loanTerms.downPaymentAmount + marketplaceFeeAmount) {
            revert InsufficientMsgValue(
                msg.value,
                offer.loanTerms.downPaymentAmount + marketplaceFeeAmount
            );
        }

        // send marketplace fee to marketplace fee recipient
        marketplaceFeeRecipient.sendValue(marketplaceFeeAmount);

        // execute buyWithSellerFinancing
        return
            INiftyApes(sellerFinancingContractAddress).buyWithSellerFinancing{
                value: msg.value - marketplaceFeeAmount
            }(offer, signature, buyer, tokenId, tokenAmount);
    }

    /// @notice Execute loan offers in batch for buyer
    /// @param offers The list of the offers to execute
    /// @param signatures The list of corresponding signatures from the offer creators
    /// @param buyer The address of the buyer
    /// @param tokenIds The tokenIds of the tokens the buyer intends to buy
    /// @param tokenAmounts The amount of the tokens the buyer intends to buy
    /// @param partialExecution If set to true, will continue to attempt transaction executions regardless
    ///        if previous transactions have failed or had insufficient value available
    function buyWithSellerFinancingBatch(
        INiftyApesStructs.Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external payable whenNotPaused returns (uint256[] memory loanIds) {
        _requireIsNotSanctioned(msg.sender);
        _requireIsNotSanctioned(buyer);

        // requireLengthOfAllInputArraysAreEqual
        if (
            offers.length != signatures.length ||
            offers.length != tokenIds.length ||
            offers.length != tokenAmounts.length
        ) {
            revert InvalidInputLength();
        }

        uint256 marketplaceFeeAccumulated;
        uint256 valueConsumed;
        loanIds = new uint256[](offers.length);

        // loop through list of offers to execute
        for (uint256 i; i < offers.length; ++i) {
            // instantiate calldata params to bypass stack too deep error
            INiftyApesStructs.Offer memory offer = offers[i];
            bytes calldata signature = signatures[i];
            uint256 tokenId = tokenIds[i];
            uint256 tokenAmount = tokenAmounts[i];
            address buyerRe = buyer;

            // calculate marketplace fee for ith offer
            uint256 marketplaceFeeAmount = ((offer.loanTerms.principalAmount +
                offer.loanTerms.downPaymentAmount) * marketplaceFeeBps) / BASE_BPS;

            // if remaining value is not sufficient to execute ith offer
            if (
                msg.value - valueConsumed < offer.loanTerms.downPaymentAmount + marketplaceFeeAmount
            ) {
                // if partial execution is allowed then move to next offer
                if (partialExecution) {
                    loanIds[i] = ~uint256(0);
                    continue;
                }
                // else revert
                else {
                    revert InsufficientMsgValue(
                        msg.value,
                        valueConsumed + offer.loanTerms.downPaymentAmount + marketplaceFeeAmount
                    );
                }
            }
            // try executing current offer,
            try
                INiftyApes(sellerFinancingContractAddress).buyWithSellerFinancing{
                    value: offer.loanTerms.downPaymentAmount
                }(offer, signature, buyerRe, tokenId, tokenAmount)
            returns (uint256 loanId) {
                loanIds[i] = loanId;
                // if successful
                // increment marketplaceFeeAccumulated
                marketplaceFeeAccumulated += marketplaceFeeAmount;
                // increment valueConsumed
                valueConsumed += offer.loanTerms.downPaymentAmount + marketplaceFeeAmount;
            } catch {
                // if failed
                // if partial execution is not allowed, revert
                if (!partialExecution) {
                    revert BuyWithSellerFinancingCallRevertedAt(i);
                }
                loanIds[i] = ~uint256(0);
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
    /// @param loanIds The list of all the token IDs
    /// @param minProfitAmounts List of minProfitAmount for each `instantSell` call
    /// @param data The list of data to be passed to each `instantSell` call
    /// @param partialExecution If set to true, will continue to attempt next request in the loop
    ///        when one `instantSell` or transfer ticket call fails
    function instantSellBatch(
        uint256[] memory loanIds,
        uint256[] memory minProfitAmounts,
        bytes[] calldata data,
        bool partialExecution
    ) external whenNotPaused {
        _requireIsNotSanctioned(msg.sender);

        uint256 executionCount = loanIds.length;
        // requireLengthOfAllInputArraysAreEqual
        if (minProfitAmounts.length != executionCount || data.length != executionCount) {
            revert InvalidInputLength();
        }

        uint256 contractBalanceBefore = address(this).balance;
        for (uint256 i; i < executionCount; ++i) {
            // intantiate loanId
            uint256 loanId = loanIds[i];
            // fetech active loan details
            INiftyApesStructs.Loan memory loan = INiftyApes(sellerFinancingContractAddress).getLoan(
                loanId
            );
            // transfer buyerNft from caller to this contract.
            // this call also ensures that loan exists and caller is the current buyer
            try
                IERC721(sellerFinancingContractAddress).safeTransferFrom(
                    msg.sender,
                    address(this),
                    loan.loanId
                )
            {
                // call instantSell to close the loan
                try
                    INiftyApes(sellerFinancingContractAddress).instantSell(
                        loanId,
                        minProfitAmounts[i],
                        data[i]
                    )
                {} catch {
                    if (!partialExecution) {
                        revert InstantSellCallRevertedAt(i);
                    } else {
                        IERC721(sellerFinancingContractAddress).safeTransferFrom(
                            address(this),
                            msg.sender,
                            loan.loanId
                        );
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
        if (valueReceived > 0) {
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
