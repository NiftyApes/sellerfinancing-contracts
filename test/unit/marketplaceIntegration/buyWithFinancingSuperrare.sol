// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestBuyWithFinancingMarketplace is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(
            boredApeYachtClub.ownerOf(offer.nftId),
            address(sellerFinancing)
        );
        // balance increments to one
        assertEq(
            sellerFinancing.balanceOf(buyer1, address(boredApeYachtClub)),
            1
        );
        // nftId exists at index 0
        assertEq(
            sellerFinancing.tokenOfOwnerByIndex(
                buyer1,
                address(boredApeYachtClub),
                0
            ),
            offer.nftId
        );
        // loan auction exists
        assertEq(
            sellerFinancing
                .getLoan(address(boredApeYachtClub), offer.nftId)
                .periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(0),
            buyer1
        );
        // seller NFT minted to seller
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(1),
            seller1
        );

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(
            loan.remainingPrincipal,
            offer.price - offer.downPaymentAmount
        );
        assertEq(
            loan.minimumPrincipalPerPeriod,
            offer.minimumPrincipalPerPeriod
        );
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(
            loan.periodEndTimestamp,
            block.timestamp + offer.periodDuration
        );
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWithFinancingMarketplace_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceFee = offer.price * SUPERRARE_MARKET_FEE_BPS / 10_000;
       
        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;
        
        vm.startPrank(buyer1);
        marketplaceIntegration.buyWithFinancing{value: offer.downPaymentAmount + marketplaceFee}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(
            marketplaceBalanceAfter,
            (marketplaceBalanceBefore + marketplaceFee)
        );
    }

    function test_fuzz_buyWithFinancingMarketplace_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMarketplace_simplest_case(fuzzed);
    }

    function test_unit_buyWithFinancingMarketplace_simplest_case() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMarketplace_simplest_case(fixedForSpeed);
    }
}
