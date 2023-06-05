// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingErrors.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";

contract TestBorrow is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoanThrough3rdPartyLender(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(borrower1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                nftId
            ),
            true
        );
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        // borrower NFT minted to borrower1
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.borrowerNftId), borrower1);
        // lender NFT minted to lender1
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.lenderNftId), lender1);

        
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );

        // check loan struct values
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_borrow_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = address(borrower1).balance;
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.nftId);
        sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.nftId
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.nftId);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = address(borrower1).balance;

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.principalAmount)
        );

        // borrower1 balance increased by loan principal amount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore + offer.principalAmount);
    }

    function test_fuzz_borrow_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_borrow_simplest_case(fuzzed);
    }

    function test_unit_borrow_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_borrow_simplest_case(fixedForSpeed);
    }
}