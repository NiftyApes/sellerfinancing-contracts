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

    function assertionsForExecutedLoan(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
        // loan auction exists
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                nftId
            ),
            true
        );
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId));

        // check loan struct values
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    // function _test_borrow_simplest_case(FuzzedOfferFields memory fuzzed) private {
    //     Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

    //     (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
    //         0x0385603ab55642cb4Dd5De3aE9e306809991804f
    //     ).getRoyalty(offer.nftContractAddress, offer.nftId, offer.downPaymentAmount);

    //     uint256 totalRoyaltiesPaid;

    //     // payout royalties
    //     for (uint256 i = 0; i < recipients1.length; i++) {
    //         totalRoyaltiesPaid += amounts1[i];
    //     }

    //     uint256 sellerBalanceBefore = address(seller1).balance;
    //     uint256 royaltiesBalanceBefore = address(recipients1[0]).balance;

    //     createOfferAndBuyWithFinancing(offer);
    //     assertionsForExecutedLoan(offer, offer.nftId);

    //     uint256 sellerBalanceAfter = address(seller1).balance;
    //     uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;

    //     // seller paid out correctly
    //     assertEq(
    //         sellerBalanceAfter,
    //         (sellerBalanceBefore + offer.downPaymentAmount - totalRoyaltiesPaid)
    //     );

    //     // royatlies paid out correctly
    //     assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    // }

    // function test_fuzz_buyWithFinancing_simplest_case(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_buyWithFinancing_simplest_case(fuzzed);
    // }

    // function test_unit_buyWithFinancing_simplest_case() public {
    //     FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
    //     _test_buyWithFinancing_simplest_case(fixedForSpeed);
    // }
}