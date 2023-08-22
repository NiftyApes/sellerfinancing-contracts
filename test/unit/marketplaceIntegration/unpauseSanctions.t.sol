// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";

contract TestUnpauseSanctionsMarketplace is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_unpauseSanctions_Marketplace_simple_case() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        vm.startPrank(owner);
        marketplaceIntegration.pauseSanctions();
        sellerFinancing.pauseSanctions();
        vm.stopPrank();

        vm.startPrank(SANCTIONED_ADDRESS);
        uint256 loanId = marketplaceIntegration.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, SANCTIONED_ADDRESS, loanId);

        vm.prank(owner);
        marketplaceIntegration.unpauseSanctions();

        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        vm.startPrank(SANCTIONED_ADDRESS);
        marketplaceIntegration.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }
}
