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

    function _test_makePayment_sellerFinancing_fullRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                (loan.loanTerms.principalAmount + periodInterest)
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
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + periodInterest) }(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(address(recipients[0]).balance, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_makePayment_sellerFinancing_fullRepayment_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_sellerFinancing_fullRepayment_simplest_case(fuzzed);
    }

    function test_unit_makePayment_sellerFinancing_fullRepayment_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_sellerFinancing_fullRepayment_simplest_case(fixedForSpeed);
    }

    function _test_makePayment_withWETH_sellerFinancing_fullRepayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = weth.balanceOf(recipients[0]);

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                (loan.loanTerms.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }
        totalRoyaltiesPaid += royaltiesPaidInMakePayment;
        
        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            weth.balanceOf(seller1),
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(weth.balanceOf(recipients[0]), (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_makePayment_withWETH_sellerFinancing_fullRepayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_withWETH_sellerFinancing_fullRepayment(fuzzed);
    }

    function test_unit_makePayment_withWETH_sellerFinancing_fullRepayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_withWETH_sellerFinancing_fullRepayment(fixedForSpeed);
    }

    function _test_makePayment_withUSDC_sellerFinancing_fullRepayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, USDC_ADDRESS);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = usdc.balanceOf(recipients[0]);

        bytes memory offerSignature = seller1CreateOffer(offer);

        mintUsdc(buyer1, offer.loanTerms.downPaymentAmount);
        vm.startPrank(buyer1);
        usdc.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                (loan.loanTerms.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }
        totalRoyaltiesPaid += royaltiesPaidInMakePayment;
        
        mintUsdc(buyer1, (loan.loanTerms.principalAmount + periodInterest));
        vm.startPrank(buyer1);
        usdc.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            usdc.balanceOf(seller1),
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(usdc.balanceOf(recipients[0]), (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_makePayment_withUSDC_sellerFinancing_fullRepayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        _test_makePayment_withUSDC_sellerFinancing_fullRepayment(fuzzed);
    }

    function test_unit_makePayment_withUSDC_sellerFinancing_fullRepayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_makePayment_withUSDC_sellerFinancing_fullRepayment(fixedForSpeed);
    }

    function _test_makePayment_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);

        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients.length; i++) {
            totalRoyaltiesPaid += amounts[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest, uint256 protocolFee) = sellerFinancing.calculateMinimumPayment(loanId);

        (recipients, amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                (loan.loanTerms.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }
        totalRoyaltiesPaid += royaltiesPaidInMakePayment;
        uint256 ownerBalanceBefore = address(owner).balance;
        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest + protocolFee,
                protocolFee,
                royaltiesPaidInMakePayment,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + periodInterest + protocolFee) }(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest + protocolFee)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest - totalRoyaltiesPaid)
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

    function _test_makePayment_sellerFinancing_withWETH_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);

        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        offer.payRoyalties = false;
        bytes memory offerSignature = seller1CreateOffer(offer);
        
        uint256 sellerBalanceBefore = weth.balanceOf(seller1);
        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest, uint256 protocolFee) = sellerFinancing.calculateMinimumPayment(loanId);

        uint256 ownerBalanceBefore = weth.balanceOf(owner);
        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest + protocolFee));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest + protocolFee,
                protocolFee,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest + protocolFee)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            weth.balanceOf(seller1),
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest)
        );

        // protocol fee received by the owner
        assertEq(weth.balanceOf(owner), ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_makePayment_sellerFinancing_withWETH_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFields(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePayment_sellerFinancing_withWETH_fullRepayment_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePayment_sellerFinancing_withWETH_fullRepayment_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_sellerFinancing_withWETH_fullRepayment_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePayment_sellerFinancing_withUSDC_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);

        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, USDC_ADDRESS);
        offer.payRoyalties = false;
        bytes memory offerSignature = seller1CreateOffer(offer);
        
        mintUsdc(buyer1, offer.loanTerms.downPaymentAmount);
        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);
        vm.startPrank(buyer1);
        usdc.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest, uint256 protocolFee) = sellerFinancing.calculateMinimumPayment(loanId);

        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        mintUsdc(buyer1, (loan.loanTerms.principalAmount + periodInterest + protocolFee));
        vm.startPrank(buyer1);
        usdc.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest + protocolFee));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest + protocolFee,
                protocolFee,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest + protocolFee)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly
        assertEq(
            usdc.balanceOf(seller1),
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest)
        );

        // protocol fee received by the owner
        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + protocolFee);
    }

    function test_fuzz_makePayment_sellerFinancing_withUSDC_fullRepayment_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        vm.assume(protocolFeeBPS < 1000);
        _test_makePayment_sellerFinancing_withUSDC_fullRepayment_withProtocolFee(fuzzed, protocolFeeBPS);
    }

    function test_unit_makePayment_sellerFinancing_withUSDC_fullRepayment_withProtocolFee() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_makePayment_sellerFinancing_withUSDC_fullRepayment_withProtocolFee(fixedForSpeed, 150);
    }

    function _test_makePayment_fullRepayment_withoutRoyalties(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.payRoyalties = false;

        uint256 sellerBalanceBefore = address(seller1).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + periodInterest) }(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        // seller paid out correctly without any royalty deductions
        assertEq(
            address(seller1).balance,
            (sellerBalanceBefore + offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount + periodInterest)
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

    function _test_makePayment_after_borrow_withWETH(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);
        mintWeth(borrower1, (periodInterest));
        uint256 lender1BalanceBefore = weth.balanceOf(lender1);

        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            weth.balanceOf(lender1),
            (lender1BalanceBefore + offer.loanTerms.principalAmount + periodInterest)
        );
    }

    function test_fuzz_makePayment_after_borrow_withWETH(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_makePayment_after_borrow_withWETH(fuzzed);
    }

    function test_unit_makePayment_after_borrow_withWETH() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_makePayment_after_borrow_withWETH(fixedForSpeed);
    }

    function _test_makePayment_after_borrow_withUSDC(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLendingUSDC);
        
        mintUsdc(lender1, offer.loanTerms.principalAmount);
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);
        uint256 lender1BalanceBefore = usdc.balanceOf(lender1);

        mintUsdc(borrower1, (loan.loanTerms.principalAmount + periodInterest));
        vm.startPrank(borrower1);
        usdc.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            usdc.balanceOf(lender1),
            (lender1BalanceBefore + offer.loanTerms.principalAmount + periodInterest)
        );
    }

    function test_fuzz_makePayment_after_borrow_withUSDC(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        _test_makePayment_after_borrow_withUSDC(fuzzed);
    }

    function test_unit_makePayment_after_borrow_withUSDC() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_makePayment_after_borrow_withUSDC(fixedForSpeed);
    }

    function _test_makePayment_after_borrow_withProtocolFee(
        FuzzedOfferFields memory fuzzed, uint96 protocolFeeBPS
    ) private {
        vm.prank(owner);
        sellerFinancing.updateProtocolFeeBPS(protocolFeeBPS);
        
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        vm.startPrank(borrower1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest, uint256 protocolFee) = sellerFinancing.calculateMinimumPayment(loanId);

        mintWeth(borrower1, (periodInterest + protocolFee));

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 ownerBalanceBefore = weth.balanceOf(owner);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest + protocolFee));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest + protocolFee,
                protocolFee,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest + protocolFee)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            weth.balanceOf(lender1),
            (lender1BalanceBefore + offer.loanTerms.principalAmount + periodInterest)
        );

        // protocol fee received by the owner
        assertEq(weth.balanceOf(owner), ownerBalanceBefore + protocolFee);
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
        boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        (uint256 loanId) = sellerFinancing.borrow(
            offer,
            offerSignature,
            borrower1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.collateralItem.tokenId, borrower1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);
        mintWeth(borrower1, (periodInterest));
        uint256 lender1BalanceBefore = weth.balanceOf(lender1);

        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), (loan.loanTerms.principalAmount + periodInterest));
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                loan.loanTerms.principalAmount + periodInterest,
                0,
                0,
                periodInterest,
                loan
        );
        vm.expectEmit(true, true, false, false);
        emit LoanRepaid(offer.collateralItem.token, offer.collateralItem.tokenId, loan);
        sellerFinancing.makePayment(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, borrower1, loanId);

        // lender received principal plus interest balance without any royalty deductions
        assertEq(
            weth.balanceOf(lender1),
            (lender1BalanceBefore + offer.loanTerms.principalAmount + periodInterest)
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;
        uint256 extraAmountToBeSent = 100;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: ((loan.loanTerms.principalAmount + periodInterest) + extraAmountToBeSent)
        }(loanId, (loan.loanTerms.principalAmount + periodInterest) + extraAmountToBeSent);
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        uint256 buyer1BalanceAfterPayment = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfterPayment,
            (buyer1BalanceBeforePayment - (loan.loanTerms.principalAmount + periodInterest))
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (uint256 totalMinimumPayment, uint256 periodInterest,) = sellerFinancing
            .calculateMinimumPayment(loanId);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, totalMinimumPayment);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 totalRoyaltiesPaid = amounts[0];

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                totalMinimumPayment,
                0,
                totalRoyaltiesPaid,
                periodInterest,
                loan
        );
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            loanId,
            totalMinimumPayment
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
            loanAfter.loanTerms.principalAmount,
            loan.loanTerms.principalAmount - (totalMinimumPayment - periodInterest)
        );

        assertEq(loanAfter.periodEndTimestamp, loan.periodEndTimestamp + loan.loanTerms.periodDuration);
        assertEq(loanAfter.periodBeginTimestamp, loan.periodBeginTimestamp + loan.loanTerms.periodDuration);
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (uint256 totalMinimumPayment, uint256 periodInterest, uint256 protocolFee) = sellerFinancing
            .calculateMinimumPayment(loanId);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, totalMinimumPayment - protocolFee);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 ownerBalanceBefore = address(owner).balance;

        vm.startPrank(buyer1);
        vm.expectEmit(true, true, false, false);
        emit PaymentMade(
                offer.collateralItem.token,
                offer.collateralItem.tokenId,
                totalMinimumPayment,
                protocolFee,
                amounts[0],
                periodInterest,
                loan
        );
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            loanId,
            totalMinimumPayment
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
            loanAfter.loanTerms.principalAmount,
            loan.loanTerms.principalAmount - (totalMinimumPayment - protocolFee - periodInterest)
        );

        assertEq(loanAfter.periodEndTimestamp, loan.periodEndTimestamp + loan.loanTerms.periodDuration);
        assertEq(loanAfter.periodBeginTimestamp, loan.periodBeginTimestamp + loan.loanTerms.periodDuration);
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.loanTerms.periodDuration);

        (, uint256 totalInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        assertEq(totalInterest, 2 * periodInterest);

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + totalInterest) }(
            loanId,
            (loan.loanTerms.principalAmount + totalInterest)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest, uint256 protocolFee) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.loanTerms.periodDuration);

        (, uint256 totalInterest, uint256 totalProtocolFee) = sellerFinancing.calculateMinimumPayment(loanId);

        assertEq(totalInterest, 2 * periodInterest);
        assertEq(totalProtocolFee, 2 * protocolFee);

        uint256 ownerBalanceBefore = address(owner).balance;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + totalInterest + totalProtocolFee) }(
            loanId,
            (loan.loanTerms.principalAmount + totalInterest + totalProtocolFee)
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);
        // protocol fee received by the owner
        assertEq(address(owner).balance, ownerBalanceBefore + totalProtocolFee);
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.loanTerms.periodDuration * 2);

        (, uint256 totalInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        assertEq(totalInterest, 3 * periodInterest);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.SoftGracePeriodEnded.selector);
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + totalInterest) }(
            loanId,
            (loan.loanTerms.principalAmount + totalInterest)
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        skip(loan.loanTerms.periodDuration);

        (uint256 totalMinimumPayment, uint256 totalInterest,) = sellerFinancing
            .calculateMinimumPayment(loanId);

        vm.assume(loan.loanTerms.principalAmount > 2 * loan.loanTerms.minimumPrincipalPerPeriod);

        assertEq(totalInterest, 2 * periodInterest);
        assertEq(totalMinimumPayment, 2 * loan.loanTerms.minimumPrincipalPerPeriod + totalInterest);

        (address payable[] memory recipients, uint256[] memory amounts) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, totalMinimumPayment);

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients[0]).balance;
        uint256 totalRoyaltiesPaid = amounts[0];

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: totalMinimumPayment }(
            loanId,
            totalMinimumPayment
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
            loanAfter.loanTerms.principalAmount,
            loan.loanTerms.principalAmount - (totalMinimumPayment - totalInterest)
        );

        assertEq(loanAfter.periodEndTimestamp, loan.periodEndTimestamp + 2 * loan.loanTerms.periodDuration);
        assertEq(
            loanAfter.periodBeginTimestamp,
            loan.periodBeginTimestamp + 2 * loan.loanTerms.periodDuration
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.makePayment{ value: (loan.loanTerms.principalAmount + periodInterest) }(
            loanId,
            (loan.loanTerms.principalAmount + periodInterest)
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: (loan.loanTerms.principalAmount + periodInterest)
        }(loanId, (loan.loanTerms.principalAmount + periodInterest));
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.makePayment{value: 1}(loanId, 1);
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.PaymentReceivedLessThanRequiredMinimumPayment.selector,
                loan.loanTerms.minimumPrincipalPerPeriod + periodInterest - 1,
                loan.loanTerms.minimumPrincipalPerPeriod + periodInterest
            )
        );
        sellerFinancing.makePayment{
            value: (loan.loanTerms.minimumPrincipalPerPeriod + periodInterest - 1)
        }(loanId, (loan.loanTerms.minimumPrincipalPerPeriod + periodInterest - 1));
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
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(
            loanId
        );

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
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
                offer.collateralItem.tokenId,
                (loan.loanTerms.principalAmount + periodInterest)
            );

        // payout royalties
        uint256 royaltiesPaidInMakePayment;
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltiesPaidInMakePayment += amounts[i];
        }

        uint256 buyer1BalanceBeforePayment = address(buyer1).balance;

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: (loan.loanTerms.principalAmount + periodInterest)
        }(loanId, (loan.loanTerms.principalAmount + periodInterest));
        vm.stopPrank();
        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer1, loanId);

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
