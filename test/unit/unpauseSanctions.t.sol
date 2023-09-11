// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestUnpauseSanctions is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer, address expectedbuyer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(SANCTIONED_ADDRESS),
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
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), expectedbuyer);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId),
            buyerTicketMetadataURI
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId));

        // check loan struct values
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function test_unit_unpauseSanctions_simple_case() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.startPrank(SANCTIONED_ADDRESS);
        sellerFinancing.buyWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.nftId,
            buyerTicketMetadataURI,
            sellerTicketMetadataURI
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, SANCTIONED_ADDRESS);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + periodInterest) }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();
    }
}
