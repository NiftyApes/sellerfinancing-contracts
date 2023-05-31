// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingErrors.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingEvents.sol";

import "../common/Console.sol";

contract TestMakePayment is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
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
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function assertionsForClosedLoan(Offer memory offer, address expectedNftOwner) private {
        // expected address has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), expectedNftOwner);
        // require delegate.cash buyer delegation has been revoked
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            false
        );
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
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients2.length; i++) {
            royaltiesPaidInMakePayment += amounts2[i];
        }
        totalRoyaltiesPaid += royaltiesPaidInMakePayment;
        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.nftContractAddress,
                offer.nftId,
                loan.remainingPrincipal + periodInterest,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.nftContractAddress, offer.nftId, loan);
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + periodInterest) }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer1);

        // seller paid out correctly
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.principalAmount + offer.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(address(recipients1[0]).balance, (royaltiesBalanceBefore + totalRoyaltiesPaid));
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

    function _test_makePayment_returns_anyExtraAmountNotReqToCloseTheLoan(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;
        uint256 extraAmountToBeSent = 100;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: ((loan.remainingPrincipal + periodInterest) + extraAmountToBeSent)
        }(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();
        assertionsForClosedLoan(offer, buyer1);

        uint256 buyer1BalanceAfterPayment = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfterPayment,
            (buyer1BalanceBeforePayment - (loan.remainingPrincipal + periodInterest))
        );
    }

    function test_fuzz_makePayment_returns_anyExtraAmountNotReqToCloseTheLoan(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_returns_anyExtraAmountNotReqToCloseTheLoan(fuzzed);
    }

    function test_unit_makePayment_returns_anyExtraAmountNotReqToCloseTheLoan() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_returns_anyExtraAmountNotReqToCloseTheLoan(fixedForSpeed);
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
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.nftContractAddress,
                offer.nftId,
                totalMinimumPayment,
                totalRoyaltiesPaid,
                periodInterest,
                loan
        );
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

    function _test_makePayment_reverts_ifCallerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

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

    function test_fuzz_makePayment_reverts_ifCallerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_reverts_ifCallerSanctioned(fuzzed);
    }

    function test_unit_makePayment_reverts_ifCallerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_reverts_ifCallerSanctioned(fixedForSpeed);
    }

    function _test_makePayment_reverts_ifLoanAlreadyClosed(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: (loan.remainingPrincipal + periodInterest)
        }(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer1);

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.makePayment{value: 1}(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();
    }

    function test_fuzz_makePayment_reverts_ifLoanAlreadyClosed(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_reverts_ifLoanAlreadyClosed(fuzzed);
    }

    function test_unit_makePayment_reverts_ifLoanAlreadyClosed() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_reverts_ifLoanAlreadyClosed(fixedForSpeed);
    }

    function _test_makePayment_reverts_ifAmountReceivedLessThanReqMinPayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.AmountReceivedLessThanRequiredMinimumPayment.selector,
                loan.minimumPrincipalPerPeriod + periodInterest - 1,
                loan.minimumPrincipalPerPeriod + periodInterest
            )
        );
        sellerFinancing.makePayment{
            value: (loan.minimumPrincipalPerPeriod + periodInterest - 1)
        }(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();
    }

    function test_fuzz_makePayment_reverts_ifAmountReceivedLessThanReqMinPayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_reverts_ifAmountReceivedLessThanReqMinPayment(fuzzed);
    }

    function test_unit_makePayment_reverts_ifAmountReceivedLessThanReqMinPayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_reverts_ifAmountReceivedLessThanReqMinPayment(fixedForSpeed);
    }

    function _test_makePayment_returns_sellerValueIfSnactioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(seller1);
        IERC721Upgradeable(address(sellerFinancing)).transferFrom(seller1, SANCTIONED_ADDRESS, loan.sellerNftId);

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();

        (address payable[] memory recipients2, uint256[] memory amounts2) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.nftContractAddress,
                offer.nftId,
                (loan.remainingPrincipal + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients2.length; i++) {
            royaltiesPaidInMakePayment += amounts2[i];
        }

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: (loan.remainingPrincipal + periodInterest)
        }(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();
        assertionsForClosedLoan(offer, buyer1);

        uint256 buyer1BalanceAfterPayment = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfterPayment,
            (buyer1BalanceBeforePayment - (royaltiesPaidInMakePayment))
        );
    }

    function test_fuzz_makePayment_returns_sellerValueIfSnactioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_returns_sellerValueIfSnactioned(fuzzed);
    }

    function test_unit_makePayment_returns_sellerValueIfSnactioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_returns_sellerValueIfSnactioned(fixedForSpeed);
    }
}
