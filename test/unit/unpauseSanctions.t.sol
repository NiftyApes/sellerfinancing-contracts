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
        assertEq(boredApeYachtClub.ownerOf(offer.item.identifier), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(SANCTIONED_ADDRESS),
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
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), expectedbuyer);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, offer.item.identifier);
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId),
            IERC721MetadataUpgradeable(offer.item.token).tokenURI(offer.item.identifier)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId));

        // check loan struct values
        assertEq(loan.borrowerNftId, 0);
        assertEq(loan.lenderNftId, 1);
        assertEq(loan.remainingPrincipal, offer.terms.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.terms.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.terms.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.terms.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.terms.periodDuration);
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
        sellerFinancing.buyWithSellerFinancing{ value: offer.terms.downPaymentAmount }(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.item.identifier
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, SANCTIONED_ADDRESS);

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, offer.item.identifier);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + periodInterest) }(
            offer.item.token,
            offer.item.identifier
        );
        vm.stopPrank();
    }
}
