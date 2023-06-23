// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../common/BaseTest.sol";
import "../../utils/fixtures/OffersLoansFixtures.sol";

contract TestUnpauseMarketplace is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.item.identifier), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.item.identifier
            ),
            true
        );
        // loan auction exists
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.item.identifier).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, offer.item.identifier);
        assertEq(loan.borrowerNftId, 0);
        assertEq(loan.lenderNftId, 1);
        assertEq(loan.remainingPrincipal, offer.terms.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.terms.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.terms.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.terms.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.terms.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function test_unit_unpause_Marketplace_simple_case() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = ((offer.terms.principalAmount + offer.terms.downPaymentAmount)* SUPERRARE_MARKET_FEE_BPS) / 10_000;

        vm.prank(owner);
        marketplaceIntegration.pause();

        vm.startPrank(buyer1);
        vm.expectRevert("Pausable: paused");
        marketplaceIntegration.buyWithSellerFinancing{ value: offer.terms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            buyer1,
            offer.item.identifier
        );
        vm.stopPrank();

        vm.prank(owner);
        marketplaceIntegration.unpause();

        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancing{ value: offer.terms.downPaymentAmount + marketplaceFee }(
            offer,
            offerSignature,
            buyer1,
            offer.item.identifier
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer);
    }
}
