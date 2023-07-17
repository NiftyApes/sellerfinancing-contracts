// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/niftyapes/INiftyApesStructs.sol";

contract TestBuyWithSellerFinancingMarketplace is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyWithSellerFinancingMarketplace_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

        vm.startPrank(buyer1);
        uint256 loanId = marketplaceIntegration.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancingMarketplace_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplace_simplest_case(fuzzed);
    }

    function test_unit_buyWithSellerFinancingMarketplace_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplace_simplest_case(fixedForSpeed);
    }

    function _test_buyWithSellerFinancingMarketplace_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.InsufficientMsgValue.selector,
                offer.loanTerms.downPaymentAmount + marketplaceFee - 1,
                offer.loanTerms.downPaymentAmount + marketplaceFee
            )
        );
        marketplaceIntegration.buyWithSellerFinancing{
            value: offer.loanTerms.downPaymentAmount + marketplaceFee - 1
        }(offer, offerSignature, buyer1, offer.collateralItem.identifier);
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancingMarketplace_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancingMarketplace_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
            fuzzed
        );
    }

    function test_unit_buyWithSellerFinancingMarketplace_reverts_ifValueSentLessThanDownpaymentPlusMarketFee()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancingMarketplace_reverts_ifValueSentLessThanDownpaymentPlusMarketFee(
            fixedForSpeed
        );
    }
}
