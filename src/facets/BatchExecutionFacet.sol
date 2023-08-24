//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../storage/NiftyApesStorage.sol";
// import "../interfaces/niftyapes/loanExecution/IBatchExecution.sol";
import "../interfaces/niftyapes/INiftyApesStructs.sol";
import "../interfaces/niftyapes/INiftyApesErrors.sol";
import "../interfaces/niftyapes/INiftyApes.sol";
import "../interfaces/seaport/ISeaport.sol";

/// @title NiftyApes BatchExecution facet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
contract NiftyApesBatchExecutionFacet is INiftyApesStructs, INiftyApesErrors {
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

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
}
