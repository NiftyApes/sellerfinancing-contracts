//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin-norm/contracts/token/ERC721/IERC721.sol";
import "../storage/NiftyApesStorage.sol";
import "../interfaces/niftyapes/batchExecution/IBatchExecution.sol";
import "../interfaces/niftyapes/INiftyApesStructs.sol";
import "../interfaces/niftyapes/INiftyApesErrors.sol";
import "../interfaces/niftyapes/INiftyApes.sol";
import "../interfaces/seaport/ISeaport.sol";

/// @title NiftyApes BatchExecution facet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract NiftyApesBatchExecutionFacet is INiftyApesStructs, INiftyApesErrors, IBatchExecution {
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @inheritdoc IBatchExecution
    function buyWithSellerFinancingBatch(
        Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external payable returns (uint256[] memory loanIds) {
        // requireLengthOfAllInputArraysAreEqual
        if (
            offers.length != signatures.length ||
            offers.length != tokenIds.length ||
            offers.length != tokenAmounts.length
        ) {
            revert InvalidInputLength();
        }

        uint256 valueConsumed;
        loanIds = new uint256[](offers.length);

        // loop through list of offers to execute
        for (uint256 i; i < offers.length; ++i) {
            // instantiate calldata params to bypass stack too deep error
            Offer memory offer = offers[i];
            bytes calldata signature = signatures[i];
            uint256 tokenId = tokenIds[i];
            uint256 tokenAmount = tokenAmounts[i];
            address buyerRe = buyer;

            // try executing current offer
            uint256 balanceBefore = address(this).balance;
            try
                INiftyApes(address(this)).buyWithSellerFinancing{
                    value: msg.value - valueConsumed
                }(offer, signature, buyerRe, tokenId, tokenAmount)
            returns (uint256 loanId) {
                loanIds[i] = loanId;
                // if successful
                // increase valueConsumed
                if (offer.loanTerms.itemType == ItemType.NATIVE) {
                    valueConsumed += balanceBefore - address(this).balance;
                }
            } catch {
                // if failed
                // if partial execution is not allowed, revert
                if (!partialExecution) {
                    revert BatchCallRevertedAt(i);
                }
                loanIds[i] = ~uint256(0);
            }
        }

        // send any unused value back to msg.sender
        if (msg.value - valueConsumed > 0) {
            payable(msg.sender).sendValue(msg.value - valueConsumed);
        }
    }

    /// @inheritdoc IBatchExecution
    function borrowBatch(
        Offer[] calldata offers,
        bytes[] calldata signatures,
        address borrower,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external returns (uint256[] memory loanIds) {
        uint256 batchLength = offers.length;
        // requireLengthOfAllInputArraysAreEqual
        if (
            batchLength != signatures.length ||
            batchLength != tokenIds.length ||
            batchLength != tokenAmounts.length
        ) {
            revert InvalidInputLength();
        }
        loanIds = new uint256[](batchLength);
        // loop through list of offers to execute
        for (uint256 i; i < batchLength; ++i) {
            // instantiate calldata params to bypass stack too deep error
            Offer memory offer = offers[i];
            try
                INiftyApes(address(this)).borrow(offer, signatures[i], borrower, tokenIds[i], tokenAmounts[i])
            returns (uint256 loanId) {
                loanIds[i] = loanId;
            } catch {
                // if failed
                // if partial execution is not allowed, revert
                if (!partialExecution) {
                    revert BatchCallRevertedAt(i);
                }
                loanIds[i] = ~uint256(0);
            }
        }
    }

    /// @inheritdoc IBatchExecution
    function buyWith3rdPartyFinancingBatch(
        INiftyApesStructs.Offer[] calldata offers,
        bytes[] calldata signatures,
        address borrower,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bytes[] calldata data,
        bool partialExecution
    ) external returns (uint256[] memory loanIds) {
        // requireLengthOfAllInputArraysAreEqual
        if (
            offers.length != signatures.length ||
            offers.length != tokenIds.length ||
            offers.length != tokenAmounts.length ||
            offers.length != data.length
        ) {
            revert InvalidInputLength();
        }
        loanIds = new uint256[](offers.length);
        // loop through list of offers to execute
        for (uint256 i; i < offers.length; ++i) {
            // instantiate calldata params to bypass stack too deep error
            Offer memory offer = offers[i];
            try
                INiftyApes(address(this)).buyWith3rdPartyFinancing(offer, signatures[i], borrower, tokenIds[i], tokenAmounts[i], data[i])
            returns (uint256 loanId) {
                loanIds[i] = loanId;
            } catch {
                // if failed
                // if partial execution is not allowed, revert
                if (!partialExecution) {
                    revert BatchCallRevertedAt(i);
                }
                loanIds[i] = ~uint256(0);
            }
        }
    }

    /// @inheritdoc IBatchExecution
    function buyNowBatch(
        Offer[] memory offers,
        bytes[] calldata signatures,
        address buyer,
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        bool partialExecution
    ) external payable {
        // requireLengthOfAllInputArraysAreEqual
        if (
            offers.length != signatures.length ||
            offers.length != tokenIds.length ||
            offers.length != tokenAmounts.length
        ) {
            revert InvalidInputLength();
        }

        uint256 valueConsumed;
        // loop through list of offers to execute
        for (uint256 i; i < offers.length; ++i) {
            // instantiate calldata params to bypass stack too deep error
            Offer memory offer = offers[i];

            // try executing current offer
            uint256 balanceBefore = address(this).balance;
            try
                INiftyApes(address(this)).buyNow{
                    value: msg.value - valueConsumed
                }(offer, signatures[i], buyer, tokenIds[i], tokenAmounts[i])
            {
                // if successful
                // increase valueConsumed
                if (offer.loanTerms.itemType == ItemType.NATIVE) {
                    valueConsumed += balanceBefore - address(this).balance;
                }
            } catch {
                // if failed
                // if partial execution is not allowed, revert
                if (!partialExecution) {
                    revert BatchCallRevertedAt(i);
                }
            }
        }
        // send any unused value back to msg.sender
        if (msg.value - valueConsumed > 0) {
            payable(msg.sender).sendValue(msg.value - valueConsumed);
        }
    }

    /// @inheritdoc IBatchExecution
    function instantSellBatch(
        uint256[] memory loanIds,
        uint256[] memory minProfitAmounts,
        bytes[] calldata data,
        bool partialExecution
    ) external {
        uint256 executionCount = loanIds.length;
        // requireLengthOfAllInputArraysAreEqual
        if (minProfitAmounts.length != executionCount || data.length != executionCount) {
            revert InvalidInputLength();
        }

        uint256 contractBalanceBefore = address(this).balance;
        for (uint256 i; i < executionCount; ++i) {
            // instantiate loanId
            uint256 loanId = loanIds[i];
            // get borrower
            address borrowerAddress = IERC721(address(this)).ownerOf(loanId);
            if (msg.sender == borrowerAddress) {
                // call instantSell to close the loan
                try
                    INiftyApes(address(this)).instantSell(
                        loanId,
                        minProfitAmounts[i],
                        data[i]
                    )
                {} catch {
                    if (!partialExecution) {
                        revert BatchCallRevertedAt(i);
                    }
                }
            } else if (!partialExecution) {
                revert BatchCallRevertedAt(i);
            }
        }
        // accumulate value received
        uint256 valueReceived = address(this).balance - contractBalanceBefore;
        // send all the amount received to the caller
        if (valueReceived > 0) {
            payable(msg.sender).sendValue(valueReceived);
        }
    }
}
