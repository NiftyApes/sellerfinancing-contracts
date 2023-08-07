// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

contract TestBuyNow is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_ETH_payment_ERC721_sale(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients1[0]).balance;

        createOfferAndBuyNow(offer);

        // buyer is the owner of the nft after the sale
        assertEq(boredApeYachtClub.ownerOf(offer.collateralItem.tokenId), buyer1);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_ETH_payment_ERC721_sale(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_ETH_payment_ERC721_sale(fuzzed);
    }

    function test_unit_ETH_payment_ERC721_sale() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_ETH_payment_ERC721_sale(fixedForSpeed);
    }

    function _test_buyNow_WETH_ERC721_sale(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = weth.balanceOf(recipients1[0]);

        createOfferAndBuyNow(offer);
        
        // buyer is the owner of the nft after the sale
        assertEq(boredApeYachtClub.ownerOf(offer.collateralItem.tokenId), buyer1);

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);
        uint256 royaltiesBalanceAfter = weth.balanceOf(recipients1[0]);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyNow_WETH_ERC721_sale(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNow_WETH_ERC721_sale(fuzzed);
    }

    function test_unit_buyNow_WETH_ERC721_sale() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNow_WETH_ERC721_sale(fixedForSpeed);
    }

    function _test_buyNow_WETH_ERC1155_sale(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155, WETH_ADDRESS);

        uint256 buyer1BalanceBefore = erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId);
        uint256 sellerBalanceBefore = weth.balanceOf(seller1);

        createOfferAndBuyNow(offer);
        
        // buyer erc1155 balance increased by sale amount
        assertEq(erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId), buyer1BalanceBefore + offer.collateralItem.amount);

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyNow_WETH_ERC1155_sale(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNow_WETH_ERC1155_sale(fuzzed);
    }

    function test_unit_buyNow_WETH_ERC1155_sale() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNow_WETH_ERC1155_sale(fixedForSpeed);
    }
}
