// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestBuyWithSellerFinancingMarketplace is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(SellerFinancingOffer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );
        // loan auction exists
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWithSellerFinancingMarketplace_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithSellerFinancing{
            value: offer.downPaymentAmount + marketplaceFee
        }(offer, offerSignature, buyer1, offer.nftId);
        vm.stopPrank();
        assertionsForExecutedLoan(offer);

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
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = (offer.price * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.InsufficientMsgValue.selector,
                offer.downPaymentAmount + marketplaceFee - 1,
                offer.downPaymentAmount + marketplaceFee
            )
        );
        marketplaceIntegration.buyWithSellerFinancing{
            value: offer.downPaymentAmount + marketplaceFee - 1
        }(offer, offerSignature, buyer1, offer.nftId);
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
