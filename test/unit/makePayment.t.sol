// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

import "../common/Console.sol";

contract TestMakePayment is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_makePayment_fullRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.identifier, offer.loanItem.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                (loan.loanItem.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }
        totalRoyaltiesPaid += royaltiesPaidInMakePayment;
        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                loan.loanItem.principalAmount + periodInterest,
                0,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.identifier, loan);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.loanItem.principalAmount + offer.loanItem.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(address(recipients[0]).balance, (royaltiesBalanceBefore + totalRoyaltiesPaid));
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

    function _test_makePayment_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);

        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.identifier, offer.loanItem.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                (loan.loanItem.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }
        totalRoyaltiesPaid += royaltiesPaidInMakePayment;
        uint256 protocolFee = sellerFinancing.calculateProtocolFee(loan.loanItem.principalAmount + periodInterest);
        uint256 ownerBalanceBefore = address(owner).balance;
        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                loan.loanItem.principalAmount + periodInterest + protocolFee,
                protocolFee,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.identifier, loan);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest + protocolFee) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.loanItem.principalAmount + offer.loanItem.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
        );

        // protocol fee received by the owner
        assertEq(address(owner).balance, ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_makePayment_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePayment_fullRepayment_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePayment_fullRepayment_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_fullRepayment_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePayment_fullRepayment_withoutRoyalties(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.payRoyalties = false;

        uint256 sellerBalanceBefore = address(seller1).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                loan.loanItem.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.identifier, loan);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        // seller paid out correctly without any royalty deductions
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.loanItem.principalAmount + offer.loanItem.downPaymentAmount + periodInterest)
        );
    }

    function test_fuzz_makePayment_fullRepayment_withoutRoyalties(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_fullRepayment_withoutRoyalties(fuzzed);
    }

    function test_unit_makePayment_fullRepayment_withoutRoyalties() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_fullRepayment_withoutRoyalties(fixedForSpeed);
    }

    function _test_makePayment_after_borrow(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.identifier);
        (uint256 loanId,) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.identifier, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        uint256 lender1BalanceBefore = address(lender1).balance;

        vm.startPrank(borrower1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                loan.loanItem.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.identifier, loan);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            address(lender1).balance,
            (lender1BalanceBefore + offer.loanItem.principalAmount + periodInterest)
        );
    }

    function test_fuzz_makePayment_after_borrow(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_after_borrow(fuzzed);
    }

    function test_unit_makePayment_after_borrow() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_after_borrow(fixedForSpeed);
    }

    function _test_makePayment_after_borrow_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);
        
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.identifier);
        (uint256 loanId,) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.identifier, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);
        uint256 protocolFee = sellerFinancing.calculateProtocolFee(loan.loanItem.principalAmount + periodInterest);

        uint256 lender1BalanceBefore = address(lender1).balance;
        uint256 ownerBalanceBefore = address(owner).balance;

        vm.startPrank(borrower1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                loan.loanItem.principalAmount + periodInterest + protocolFee,
                protocolFee,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.identifier, loan);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest + protocolFee) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            address(lender1).balance,
            (lender1BalanceBefore + offer.loanItem.principalAmount + periodInterest)
        );

        // protocol fee received by the owner
        assertEq(address(owner).balance, ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_makePayment_after_borrow_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePayment_after_borrow_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePayment_after_borrow_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_after_borrow_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePayment_after_borrow_payRoyaltiesIgnored_whenSetToTrue(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        offer.payRoyalties = true;

        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.identifier);
        (uint256 loanId,) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.identifier, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        uint256 lender1BalanceBefore = address(lender1).balance;

        vm.startPrank(borrower1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                loan.loanItem.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.identifier, loan);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            address(lender1).balance,
            (lender1BalanceBefore + offer.loanItem.principalAmount + periodInterest)
        );
    }

    function test_fuzz_makePayment_after_borrow_payRoyaltiesIgnored_whenSetToTrue(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_after_borrow_payRoyaltiesIgnored_whenSetToTrue(fuzzed);
    }

    function test_unit_makePayment_after_borrow_payRoyaltiesIgnored_whenSetToTrue() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_after_borrow_payRoyaltiesIgnored_whenSetToTrue(fixedForSpeed);
    }

    function _test_makePayment_returns_anyExtraAmountNotReqToCloseTheLoan(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;
        uint256 extraAmountToBeSent = 100;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: ((loan.loanItem.principalAmount + periodInterest) + extraAmountToBeSent)
        }(loanId);
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        uint256 buyer1BalanceAfterPayment = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfterPayment,
            (buyer1BalanceBeforePayment - (loan.loanItem.principalAmount + periodInterest))
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (uint256 totalMinimumPayment, uint256 periodInterest) = sellerFinancing
            .calculateMinimumPayment(loanId);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.identifier, totalMinimumPayment);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 totalRoyaltiesPaid = amounts[0];

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                totalMinimumPayment,
                0,
                totalRoyaltiesPaid,
                periodInterest,
                loan
        );
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            loanId
        );
        vm.stopPrank();

        Loan memory loanAfter = sellerFinancing.getLoan(loanId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients[0]).balance;

        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + totalMinimumPayment - totalRoyaltiesPaid)
        );

        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));

        assertEq(
            loanAfter.loanItem.principalAmount,
            loan.loanItem.principalAmount - (totalMinimumPayment - periodInterest)
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

    function _test_makePayment_partialRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);
        
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (uint256 totalMinimumPayment, uint256 periodInterest) = sellerFinancing
            .calculateMinimumPayment(loanId);

        uint256 protocolFee = sellerFinancing.calculateProtocolFee(loan.loanItem.minimumPrincipalPerPeriod + periodInterest);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.identifier, totalMinimumPayment - protocolFee);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 ownerBalanceBefore = address(owner).balance;

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                totalMinimumPayment,
                protocolFee,
                amounts[0],
                periodInterest,
                loan
        );
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            loanId
        );
        vm.stopPrank();

        Loan memory loanAfter = sellerFinancing.getLoan(loanId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients[0]).balance;

        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + totalMinimumPayment - protocolFee - amounts[0])
        );

        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + amounts[0]));

        assertEq(
            loanAfter.loanItem.principalAmount,
            loan.loanItem.principalAmount - (totalMinimumPayment - protocolFee - periodInterest)
        );

        assertEq(loanAfter.periodEndTimestamp, loan.periodEndTimestamp + loan.periodDuration);
        assertEq(loanAfter.periodBeginTimestamp, loan.periodBeginTimestamp + loan.periodDuration);
        // protocol fee received by the owner
        assertEq(address(owner).balance, ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_makePayment_partialRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePayment_partialRepayment_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePayment_partialRepayment_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_partialRepayment_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePayment_fullRepayment_in_gracePeriod(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.periodDuration);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        assertEq(totalInterest, 2 * periodInterest);

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + totalInterest) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);
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

    function _test_makePayment_fullRepayment_in_gracePeriod_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);
        
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.periodDuration);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        assertEq(totalInterest, 2 * periodInterest);

        uint256 ownerBalanceBefore = address(owner).balance;
        
        uint256 protocolFee = sellerFinancing.calculateProtocolFee(loan.loanItem.principalAmount + totalInterest);

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + totalInterest + protocolFee) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);
        // protocol fee received by the owner
        assertEq(address(owner).balance, ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_makePayment_fullRepayment_in_gracePeriod_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePayment_fullRepayment_in_gracePeriod_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePayment_fullRepayment_in_gracePeriod_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_fullRepayment_in_gracePeriod_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePayment_reverts_if_post_grace_period(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.periodDuration * 2);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        assertEq(totalInterest, 3 * periodInterest);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + totalInterest) }(
            loanId
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

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.periodDuration);

        (uint256 totalMinimumPayment, uint256 totalInterest) = sellerFinancing
            .calculateMinimumPayment(loanId);

        vm.assume(loan.loanItem.principalAmount > 2 * loan.loanItem.minimumPrincipalPerPeriod);

        assertEq(totalInterest, 2 * periodInterest);
        assertEq(totalMinimumPayment, 2 * loan.loanItem.minimumPrincipalPerPeriod + totalInterest);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.identifier, totalMinimumPayment);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 totalRoyaltiesPaid = amounts[0];

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            loanId
        );
        vm.stopPrank();

        Loan memory loanAfter = sellerFinancing.getLoan(loanId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients[0]).balance;

        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + totalMinimumPayment - totalRoyaltiesPaid)
        );

        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));

        assertEq(
            loanAfter.loanItem.principalAmount,
            loan.loanItem.principalAmount - (totalMinimumPayment - totalInterest)
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
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest) }(
            loanId
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
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: (loan.loanItem.principalAmount + periodInterest)
        }(loanId);
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.makePayment{value: 1}(loanId);
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
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.AmountReceivedLessThanRequiredMinimumPayment.selector,
                loan.loanItem.minimumPrincipalPerPeriod + periodInterest - 1,
                loan.loanItem.minimumPrincipalPerPeriod + periodInterest
            )
        );
        sellerFinancing.makePayment{
            value: (loan.loanItem.minimumPrincipalPerPeriod + periodInterest - 1)
        }(loanId);
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
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(seller1);
        IERC721Upgradeable(address(sellerFinancing)).transferFrom(seller1, SANCTIONED_ADDRESS, loanId + 1);

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.identifier,
                (loan.loanItem.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: (loan.loanItem.principalAmount + periodInterest)
        }(loanId);
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

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
