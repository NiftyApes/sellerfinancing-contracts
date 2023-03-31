// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingErrors.sol";

import "../common/Console.sol";

contract TestMakePayment is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), address(sellerFinancing));
        // balance increments to one
        assertEq(sellerFinancing.balanceOf(buyer1, address(boredApeYachtClub)), 1);
        // nftId exists at index 0
        assertEq(
            sellerFinancing.tokenOfOwnerByIndex(buyer1, address(boredApeYachtClub), 0),
            offer.nftId
        );
        // loan exists
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

    function assertionsForClosedLoan(Offer memory offer, address expectedNftOwner) private {
        // expected address has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), expectedNftOwner);

        // loan reciept balance decrements to zero
        assertEq(sellerFinancing.balanceOf(buyer1, address(boredApeYachtClub)), 0);

        assertEq(sellerFinancing.balanceOf(seller1, address(boredApeYachtClub)), 0);
        // nftId does not exist at index 0
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.InvalidIndex.selector, 0, 0));
        assertEq(sellerFinancing.tokenOfOwnerByIndex(buyer1, address(boredApeYachtClub), 0), 0);

        // nftId does not exist at index 0
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.InvalidIndex.selector, 1, 0));
        assertEq(sellerFinancing.tokenOfOwnerByIndex(buyer1, address(boredApeYachtClub), 1), 0);
        // loan doesn't exist anymore
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            0
        );
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), address(0));
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), address(0));
    }

    function _test_makePayment_fullRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, offer.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients1[0]).balance;

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        (address payable[] memory recipients2, uint256[] memory amounts2) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.nftContractAddress,
                offer.nftId,
                (loan.remainingPrincipal + periodInterest)
            );

        // payout royalties
        for (uint256 i = 0; i < recipients2.length; i++) {
            totalRoyaltiesPaid += amounts2[i];
        }
        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + periodInterest) }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer1);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.price + periodInterest - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_makePayment_fullRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_fullRepayment_simplest_case(fuzzed);
    }

    function test_unit_makePayment_fullRepayment_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_fullRepayment_simplest_case(fixedForSpeed);
    }

    function _test_makePayment_partialRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (uint256 totalMinimumPayment, uint256 periodInterest) = sellerFinancing
            .calculateMinimumPayment(loan);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, totalMinimumPayment);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 totalRoyaltiesPaid = amounts[0];

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();

        Loan memory loanAfter = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients[0]).balance;

        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + totalMinimumPayment - totalRoyaltiesPaid)
        );

        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));

        assertEq(
            loanAfter.remainingPrincipal,
            loan.remainingPrincipal - (totalMinimumPayment - periodInterest)
        );

        assertEq(loanAfter.periodEndTimestamp, loan.periodEndTimestamp + loan.periodDuration);
        assertEq(loanAfter.periodBeginTimestamp, loan.periodBeginTimestamp + loan.periodDuration);
    }

    function test_fuzz_makePayment_partialRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_partialRepayment_simplest_case(fuzzed);
    }

    function test_unit_makePayment_partialRepayment_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_partialRepayment_simplest_case(fixedForSpeed);
    }

    function _test_makePayment_fullRepayment_in_gracePeriod(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        skip(loan.periodDuration);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loan);

        assertEq(totalInterest, 2 * periodInterest);

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + totalInterest) }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer1);
    }

    function test_fuzz_makePayment_fullRepayment_in_gracePeriod(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_fullRepayment_in_gracePeriod(fuzzed);
    }

    function test_unit_makePayment_fullRepayment_in_gracePeriod() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_fullRepayment_in_gracePeriod(fixedForSpeed);
    }

    function _test_makePayment_reverts_if_post_grace_period(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        skip(loan.periodDuration * 2);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loan);

        assertEq(totalInterest, 3 * periodInterest);

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + totalInterest) }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();
    }

    function test_fuzz_makePayment_reverts_if_post_grace_period(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_reverts_if_post_grace_period(fuzzed);
    }

    function test_unit_makePayment_reverts_if_post_grace_period() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_reverts_if_post_grace_period(fixedForSpeed);
    }

    function _test_makePayment_partialRepayment_in_grace_period(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        skip(loan.periodDuration);

        (uint256 totalMinimumPayment, uint256 totalInterest) = sellerFinancing
            .calculateMinimumPayment(loan);

        vm.assume(loan.remainingPrincipal > 2 * loan.minimumPrincipalPerPeriod);

        assertEq(totalInterest, 2 * periodInterest);
        assertEq(totalMinimumPayment, 2 * loan.minimumPrincipalPerPeriod + totalInterest);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, totalMinimumPayment);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 totalRoyaltiesPaid = amounts[0];

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();

        Loan memory loanAfter = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients[0]).balance;

        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + totalMinimumPayment - totalRoyaltiesPaid)
        );

        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));

        assertEq(
            loanAfter.remainingPrincipal,
            loan.remainingPrincipal - (totalMinimumPayment - totalInterest)
        );

        assertEq(loanAfter.periodEndTimestamp, loan.periodEndTimestamp + 2 * loan.periodDuration);
        assertEq(
            loanAfter.periodBeginTimestamp,
            loan.periodBeginTimestamp + 2 * loan.periodDuration
        );
    }

    function test_fuzz_makePayment_partialRepayment_in_grace_period(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_partialRepayment_in_grace_period(fuzzed);
    }

    function test_unit_makePayment_partialRepayment_in_grace_period() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_partialRepayment_in_grace_period(fixedForSpeed);
    }
}
