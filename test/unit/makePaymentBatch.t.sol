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

contract TestMakePaymentBatch is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_makePaymentBatch_fullRepayment_case_with_oneLoan(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;
        uint256[] memory payments = new uint256[](1);
        payments[0] = (loan.loanTerms.principalAmount + periodInterest);
        sellerFinancing.makePaymentBatch{ value:  payments[0]}(
            loanIds,
            payments,
            false
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);
    }

    function test_fuzz_makePaymentBatch_fullRepayment_case_with_oneLoan(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePaymentBatch_fullRepayment_case_with_oneLoan(fuzzed);
    }

    function test_unit_makePaymentBatch_fullRepayment_case_with_oneLoan() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePaymentBatch_fullRepayment_case_with_oneLoan(fixedForSpeed);
    }

    function _test_makePaymentBatch_fullRepayment_case_with_twoLoans(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.identifier = 0;
        uint256 nftId1 = 8661;
        uint256 nftId2 = 6974;

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1, nftId2);
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId2);
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256 loanId1 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        uint256 loanId2 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1, buyer1, loanId1);
        assertionsForExecutedLoan(offer, nftId2, buyer1, loanId2);

        Loan memory loan1 = sellerFinancing.getLoan(loanId1);
        Loan memory loan2 = sellerFinancing.getLoan(loanId2);

        (, uint256 periodInterest1,) = sellerFinancing.calculateMinimumPayment(loanId1);
        (, uint256 periodInterest2,) = sellerFinancing.calculateMinimumPayment(loanId2);

        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = loanId1;
        loanIds[1] = loanId2;
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.loanTerms.principalAmount + periodInterest1);
        payments[1] = (loan2.loanTerms.principalAmount + periodInterest2);

        vm.startPrank(buyer1);
        sellerFinancing.makePaymentBatch{ value:  payments[0]+payments[1]}(
            loanIds,
            payments,
            false
        );
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, nftId1, buyer1, loanIds[0]);
        assertionsForClosedLoan(offer.collateralItem.token, nftId2, buyer1, loanIds[1]);
    }

    function test_fuzz_makePaymentBatch_fullRepayment_case_with_twoLoans(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePaymentBatch_fullRepayment_case_with_twoLoans(fuzzed);
    }

    function test_unit_makePaymentBatch_fullRepayment_case_with_twoLoans() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePaymentBatch_fullRepayment_case_with_twoLoans(fixedForSpeed);
    }

    function _test_makePaymentBatch_fullRepayment_case_with_twoLoans_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);

        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.identifier = 0;
        uint256 nftId1 = 8661;
        uint256 nftId2 = 6974;

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1, nftId2);
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId2);
        vm.stopPrank();

        uint256[] memory loanIds = new uint256[](2);
        vm.startPrank(buyer1);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1, buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, nftId2, buyer1, loanIds[1]);

        Loan memory loan1 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan2 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterest1,uint256 protocolFee1) = sellerFinancing.calculateMinimumPayment(loanIds[0]);
        (, uint256 periodInterest2,uint256 protocolFee2) = sellerFinancing.calculateMinimumPayment(loanIds[1]);

        
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.loanTerms.principalAmount + periodInterest1 + protocolFee1);
        payments[1] = (loan2.loanTerms.principalAmount + periodInterest2 + protocolFee2);

        vm.startPrank(buyer1);
        sellerFinancing.makePaymentBatch{ value:  payments[0]+payments[1]}(
            loanIds,
            payments,
            false
        );
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, nftId1, buyer1, loanIds[0]);
        assertionsForClosedLoan(offer.collateralItem.token, nftId2, buyer1, loanIds[1]);
    }

    function test_fuzz_makePaymentBatch_fullRepayment_case_with_twoLoans_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePaymentBatch_fullRepayment_case_with_twoLoans_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePaymentBatch_fullRepayment_case_with_twoLoans_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePaymentBatch_fullRepayment_case_with_twoLoans_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePaymentBatch_returns_anyExtraAmountNotReqToCloseTheLoan(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;
        uint256 extraAmountToBeSent = 100;

        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;
        uint256[] memory payments = new uint256[](1);
        payments[0] = (loan.loanTerms.principalAmount + periodInterest);
        sellerFinancing.makePaymentBatch{ value:  (payments[0] + extraAmountToBeSent)}(
            loanIds,
            payments,
            false
        );
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        uint256 buyer1BalanceAfterPayment = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfterPayment,
            (buyer1BalanceBeforePayment - (loan.loanTerms.principalAmount + periodInterest))
        );
    }

    function test_fuzz_makePaymentBatch_returns_anyExtraAmountNotReqToCloseTheLoan(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePaymentBatch_returns_anyExtraAmountNotReqToCloseTheLoan(fuzzed);
    }

    function test_unit_makePaymentBatch_returns_anyExtraAmountNotReqToCloseTheLoan() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePaymentBatch_returns_anyExtraAmountNotReqToCloseTheLoan(fixedForSpeed);
    }

    function _test_makePaymentBatch_partialRepayment_case_two_loans(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.identifier = 0;
        uint256 nftId1 = 8661;
        uint256 nftId2 = 6974;

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1, nftId2);
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId2);
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256 loanId1 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        uint256 loanId2 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1, buyer1, loanId1);
        assertionsForExecutedLoan(offer, nftId2, buyer1, loanId2);

        Loan memory loan1 = sellerFinancing.getLoan(loanId1);
        Loan memory loan2 = sellerFinancing.getLoan(loanId2);

        (, uint256 periodInterest1,) = sellerFinancing.calculateMinimumPayment(loanId1);
        (, uint256 periodInterest2,) = sellerFinancing.calculateMinimumPayment(loanId2);

        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = loanId1;
        loanIds[1] = loanId2;
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.loanTerms.minimumPrincipalPerPeriod + periodInterest1);
        payments[1] = (loan2.loanTerms.minimumPrincipalPerPeriod + periodInterest2);

        vm.startPrank(buyer1);
        sellerFinancing.makePaymentBatch{ value:  payments[0]+payments[1]}(
            loanIds,
            payments,
            false
        );
        vm.stopPrank();
        Loan memory loan1_after = sellerFinancing.getLoan(loanId1);
        Loan memory loan2_after = sellerFinancing.getLoan(loanId2);
        assertEq(loan1_after.loanTerms.principalAmount, loan1.loanTerms.principalAmount - loan1.loanTerms.minimumPrincipalPerPeriod);
        assertEq(loan2_after.loanTerms.principalAmount, loan2.loanTerms.principalAmount - loan1.loanTerms.minimumPrincipalPerPeriod);
    }

    function test_fuzz_makePaymentBatch_partialRepayment_case_two_loans(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePaymentBatch_partialRepayment_case_two_loans(fuzzed);
    }

    function test_unit_makePaymentBatch_partialRepayment_case_two_loans() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePaymentBatch_partialRepayment_case_two_loans(fixedForSpeed);
    }

    function _test_makePaymentBatch_partialExecution_case_two_loans(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;
        offer.collateralItem.identifier = 0;
        uint256 nftId1 = 8661;
        uint256 nftId2 = 6974;

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1, nftId2);
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId2);
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256 loanId1 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        uint256 loanId2 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1, buyer1, loanId1);
        assertionsForExecutedLoan(offer, nftId2, buyer1, loanId2);

        Loan memory loan1 = sellerFinancing.getLoan(loanId1);
        Loan memory loan2 = sellerFinancing.getLoan(loanId2);

        (, uint256 periodInterest1,) = sellerFinancing.calculateMinimumPayment(loanId1);
        (, uint256 periodInterest2,) = sellerFinancing.calculateMinimumPayment(loanId2);

        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = loanId1;
        loanIds[1] = loanId2;
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.loanTerms.minimumPrincipalPerPeriod + periodInterest1);
        payments[1] = (loan2.loanTerms.minimumPrincipalPerPeriod + periodInterest2);

        vm.startPrank(buyer1);
        uint256 buyer1BalanceBefore = address(buyer1).balance;
        sellerFinancing.makePaymentBatch{ value:  payments[0] + payments[1] - 1}(
            loanIds,
            payments,
            true
        );
        vm.stopPrank();
        Loan memory loan1_after = sellerFinancing.getLoan(loanId1);
        Loan memory loan2_after = sellerFinancing.getLoan(loanId2);
        assertEq(loan1_after.loanTerms.principalAmount, loan1.loanTerms.principalAmount - loan1.loanTerms.minimumPrincipalPerPeriod);
        assertEq(loan2_after.loanTerms.principalAmount, loan2.loanTerms.principalAmount);
        
        uint256 buyer1BalanceAfter = address(buyer1).balance;
        assertEq(buyer1BalanceAfter, buyer1BalanceBefore - payments[0]);
    }

    function test_fuzz_makePaymentBatch_partialExecution_case_two_loans(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePaymentBatch_partialExecution_case_two_loans(fuzzed);
    }

    function test_unit_makePaymentBatch_partialExecution_case_two_loans() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePaymentBatch_partialExecution_case_two_loans(fixedForSpeed);
    }
}
