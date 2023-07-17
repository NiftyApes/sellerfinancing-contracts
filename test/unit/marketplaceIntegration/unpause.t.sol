// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";

contract TestUnpauseMarketplace is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_unpause_Marketplace_simple_case() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount)* SUPERRARE_MARKET_FEE_BPS) / 10_000;

        vm.prank(owner);
        marketplaceIntegration.pause();

        vm.startPrank(buyer1);
        vm.expectRevert("Pausable: paused");
        marketplaceIntegration.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();

        vm.prank(owner);
        marketplaceIntegration.unpause();

        vm.startPrank(buyer1);
        uint256 loanId = marketplaceIntegration.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);
    }
}
