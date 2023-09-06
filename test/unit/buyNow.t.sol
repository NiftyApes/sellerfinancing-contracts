// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

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

    function _test_buyNow_USDC_ERC1155_sale(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155, USDC_ADDRESS);
        mintUsdc(buyer1, offer.loanTerms.downPaymentAmount);

        uint256 buyer1BalanceBefore = erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId);
        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);
        
        createOfferAndBuyNow(offer);
        
        // buyer erc1155 balance increased by sale amount
        assertEq(erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId), buyer1BalanceBefore + offer.collateralItem.amount);

        uint256 sellerBalanceAfter = usdc.balanceOf(seller1);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyNow_USDC_ERC1155_sale(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed){
        _test_buyNow_USDC_ERC1155_sale(fuzzed);
    }

    function test_unit_buyNow_USDC_ERC1155_sale() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_buyNow_USDC_ERC1155_sale(fixedForSpeed);
    }

    function _test_buyNow_USDC_ERC1155_emits_correct_events(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155, USDC_ADDRESS);
        mintUsdc(buyer1, offer.loanTerms.downPaymentAmount);

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        usdc.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
        vm.expectEmit(true, true, false, false);
        emit SaleExecuted(
            offer.collateralItem.token,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount,
            offer.loanTerms.token,
            offer.loanTerms.downPaymentAmount
        );
        sellerFinancing.buyNow(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyNow_USDC_ERC1155_emits_correct_events(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed){
        _test_buyNow_USDC_ERC1155_emits_correct_events(fuzzed);
    }

    function test_unit_buyNow_USDC_ERC1155_emits_correct_events() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_buyNow_USDC_ERC1155_emits_correct_events(fixedForSpeed);
    }

    function _test_buyNow_WETH_ERC1155_collectionOffer(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155, WETH_ADDRESS);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        uint256 buyer1BalanceBefore = erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId);
        uint256 sellerBalanceBefore = weth.balanceOf(seller1);

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount * 2);
        sellerFinancing.buyNow(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        sellerFinancing.buyNow(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        
        // buyer erc1155 balance increased by purchased amount
        assertEq(erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId), buyer1BalanceBefore + offer.collateralItem.amount * 2);

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + 2 * offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyNow_WETH_ERC1155_collectionOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNow_WETH_ERC1155_collectionOffer(fuzzed);
    }

    function test_unit_buyNow_WETH_ERC1155_collectionOffer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNow_WETH_ERC1155_collectionOffer(fixedForSpeed);
    }

    function _test_buyNow_reverts_if_OfferType_notSALE(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        offer.offerType = OfferType.LENDING;

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidOfferType.selector,
                OfferType.LENDING,
                OfferType.SALE
            )
        );
        sellerFinancing.buyNow(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyNow_reverts_if_OfferType_notSALE(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNow_reverts_if_OfferType_notSALE(fuzzed);
    }

    function test_unit_buyNow_reverts_if_OfferType_notSALE() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNow_reverts_if_OfferType_notSALE(fixedForSpeed);
    }

    function _test_buyNow_reverts_if_insufficient_msgValue(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InsufficientMsgValue.selector,
                offer.loanTerms.downPaymentAmount-1,
                offer.loanTerms.downPaymentAmount
            )
        );
        sellerFinancing.buyNow{value: offer.loanTerms.downPaymentAmount-1}(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyNow_reverts_if_insufficient_msgValue(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNow_reverts_if_insufficient_msgValue(fuzzed);
    }

    function test_unit_buyNow_reverts_if_insufficient_msgValue() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNow_reverts_if_insufficient_msgValue(fixedForSpeed);
    }

    function _test_buyNow_WETH_ERC1155_collectionOffer_reverts_if_limitReached(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155, WETH_ADDRESS);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 1;

        uint256 buyer1BalanceBefore = erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId);
        uint256 sellerBalanceBefore = weth.balanceOf(seller1);

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount * 2);
        sellerFinancing.buyNow(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.expectRevert(INiftyApesErrors.CollectionOfferLimitReached.selector);
        sellerFinancing.buyNow(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        
        // buyer erc1155 balance increased by only one times the offer
        assertEq(erc1155Token.balanceOf(buyer1, offer.collateralItem.tokenId), buyer1BalanceBefore + offer.collateralItem.amount);

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyNow_WETH_ERC1155_collectionOffer_reverts_if_limitReached(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyNow_WETH_ERC1155_collectionOffer_reverts_if_limitReached(fuzzed);
    }

    function test_unit_buyNow_WETH_ERC1155_collectionOffer_reverts_if_limitReached() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyNow_WETH_ERC1155_collectionOffer_reverts_if_limitReached(fixedForSpeed);
    }

    function _test_ETH_payment_ERC721_sale_withMarketplaceFees(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = saleOfferStructFromFields(fuzzed, defaultFixedOfferFields, address(0));
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        offer.marketplaceRecipients = new MarketplaceRecipient[](1);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);

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

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyNow{ value: offer.loanTerms.downPaymentAmount + marketplaceFee}(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );

        // buyer is the owner of the nft after the sale
        assertEq(boredApeYachtClub.ownerOf(offer.collateralItem.tokenId), buyer1);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;
        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_ETH_payment_ERC721_sale_withMarketplaceFees(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_ETH_payment_ERC721_sale_withMarketplaceFees(fuzzed);
    }

    function test_unit_ETH_payment_ERC721_sale_withMarketplaceFees() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_ETH_payment_ERC721_sale_withMarketplaceFees(fixedForSpeed);
    }
}
