// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

contract TestBuyWithSellerFinancing is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_buyWithSellerFinancing_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients1[0]).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithSellerFinancing_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_simplest_case(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_simplest_case(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_WETH_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = weth.balanceOf(recipients1[0]);

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

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);
        uint256 royaltiesBalanceAfter = weth.balanceOf(recipients1[0]);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithSellerFinancing_WETH_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_WETH_simplest_case(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_WETH_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_WETH_simplest_case(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_USDC_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, address(usdc));

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = usdc.balanceOf(recipients1[0]);

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

        uint256 sellerBalanceAfter = usdc.balanceOf(seller1);
        uint256 royaltiesBalanceAfter = usdc.balanceOf(recipients1[0]);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithSellerFinancing_USDC_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        _test_buyWithSellerFinancing_USDC_simplest_case(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_USDC_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_buyWithSellerFinancing_USDC_simplest_case(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_loanETH_collateralERC1155(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155);

        uint256 sellerBalanceBefore = address(seller1).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoanERC1155(offer, offer.collateralItem.tokenId, offer.collateralItem.amount, buyer1, loanId, offer.collateralItem.amount);

        uint256 sellerBalanceAfter = address(seller1).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_loanETH_collateralERC1155(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_loanETH_collateralERC1155(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_loanETH_collateralERC1155() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_loanETH_collateralERC1155(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_loanWETH_collateralERC1155(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFieldsERC1155, WETH_ADDRESS);

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);

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
        
        assertionsForExecutedLoanERC1155(offer, offer.collateralItem.tokenId, offer.collateralItem.amount, buyer1, loanId, offer.collateralItem.amount);

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_loanWETH_collateralERC1155(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_loanWETH_collateralERC1155(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_loanWETH_collateralERC1155() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_loanWETH_collateralERC1155(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_loanUSDC_collateralERC1155(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFieldsERC1155, address(usdc));

        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);
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
        
        assertionsForExecutedLoanERC1155(offer, offer.collateralItem.tokenId, offer.collateralItem.amount, buyer1, loanId, offer.collateralItem.amount);

        uint256 sellerBalanceAfter = usdc.balanceOf(seller1);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_loanUSDC_collateralERC1155(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        _test_buyWithSellerFinancing_loanUSDC_collateralERC1155(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_loanUSDC_collateralERC1155() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_buyWithSellerFinancing_loanUSDC_collateralERC1155(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_withoutRoyaltyPayments_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.payRoyalties = false;

        uint256 sellerBalanceBefore = address(seller1).balance;

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        uint256 sellerBalanceAfter = address(seller1).balance;

        // seller paid out correctly without any royalty deductions
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_withoutRoyaltyPayments_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_withoutRoyaltyPayments_simplest_case(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withoutRoyaltyPayments_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_withoutRoyaltyPayments_simplest_case(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_withoutRoyaltyPayments_WETH(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        offer.payRoyalties = false;

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);

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

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);

        // seller paid out correctly without any royalty deductions
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_withoutRoyaltyPayments_WETH(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_withoutRoyaltyPayments_WETH(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withoutRoyaltyPayments_WETH() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_withoutRoyaltyPayments_WETH(fixedForSpeed);
    }
    
    function _test_buyWithSellerFinancing_withoutRoyaltyPayments_USDC(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, USDC_ADDRESS);
        offer.payRoyalties = false;

        uint256 sellerBalanceBefore = usdc.balanceOf(seller1);

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

        uint256 sellerBalanceAfter = usdc.balanceOf(seller1);

        // seller paid out correctly without any royalty deductions
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_withoutRoyaltyPayments_USDC(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFieldsForUSDC(fuzzed) {
        _test_buyWithSellerFinancing_withoutRoyaltyPayments_USDC(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withoutRoyaltyPayments_USDC() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTestingUSDC;
        _test_buyWithSellerFinancing_withoutRoyaltyPayments_USDC(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_returnsExtraAmountMoreThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        // set any value > 0
        uint256 extraAmount = 1234;
        uint256 buyer1BalanceBefore = address(buyer1).balance;
        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount + extraAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        // assert only offer.loanTerms.downPaymentAmount is consumed and extraAmount is returned
        uint256 buyer1BalanceAfter = address(buyer1).balance;
        assertEq(buyer1BalanceAfter, buyer1BalanceBefore - offer.loanTerms.downPaymentAmount);
    }

    function test_fuzz_buyWithSellerFinancing_returnsExtraAmountMoreThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_returnsExtraAmountMoreThanDownpayment(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_returnsExtraAmountMoreThanDownpayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_returnsExtraAmountMoreThanDownpayment(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_emitsExpectedEvents(FuzzedOfferFields memory fuzzed) private {
        INiftyApesStructs.Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        Loan memory loan = sellerFinancing.getLoan(0);

        vm.expectEmit(true, true, false, false);
        emit OfferSignatureUsed(offer.collateralItem.token, offer.collateralItem.tokenId, offer, offerSignature);

        vm.expectEmit(true, true, false, false);
        emit LoanExecuted(offer.collateralItem.token, offer.collateralItem.tokenId, offer.collateralItem.amount, offerSignature, loan);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_emitsExpectedEvents(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_emitsExpectedEvents(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_emitsExpectedEvents() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_emitsExpectedEvents(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_collection_offer(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 tokenId = offer.collateralItem.tokenId;
        offer.isCollectionOffer = true;

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = address(seller1).balance;
        uint256 royaltiesBalanceBefore = address(recipients1[0]).balance;

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenId);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        Loan memory loan = sellerFinancing.getLoan(0);

        vm.expectEmit(true, true, false, false);
        emit LoanExecuted(offer.collateralItem.token, tokenId, offer.collateralItem.amount, offerSignature, loan);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenId,
            0
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenId, buyer1, loanId);

        uint256 sellerBalanceAfter = address(seller1).balance;
        uint256 royaltiesBalanceAfter = address(recipients1[0]).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithSellerFinancing_collection_offer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_collection_offer(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_collection_offer() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_collection_offer(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_collection_offer_withERC1155(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFieldsERC1155);
        uint256 tokenId = offer.collateralItem.tokenId;
        uint256 tokenAmount = offer.collateralItem.amount;
        offer.isCollectionOffer = true;

        uint256 sellerBalanceBefore = address(seller1).balance;

        vm.startPrank(seller1);
        erc1155Token.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        Loan memory loan = sellerFinancing.getLoan(0);

        vm.expectEmit(true, true, false, false);
        emit LoanExecuted(offer.collateralItem.token, tokenId, tokenAmount, offerSignature, loan);
        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenId,
            tokenAmount
        );
        vm.stopPrank();

        assertionsForExecutedLoanERC1155(offer, tokenId, tokenAmount, buyer1, loanId, tokenAmount);
        uint256 sellerBalanceAfter = address(seller1).balance;

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount)
        );
    }

    function test_fuzz_buyWithSellerFinancing_collection_offer_withERC1155(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_collection_offer_withERC1155(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_collection_offer_withERC1155() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_collection_offer_withERC1155(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_tokenIdNotEqualToOfferNftId_for_nonCollectionOffer(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.CollateralDetailsMustMatch.selector);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId + 1,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_tokenIdNotEqualToOfferNftId_for_nonCollectionOffer(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_tokenIdNotEqualToOfferNftId_for_nonCollectionOffer(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_tokenIdNotEqualToOfferNftId_for_nonCollectionOffer()
        public
    {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_tokenIdNotEqualToOfferNftId_for_nonCollectionOffer(
            fixedForSpeed
        );
    }

    function _test_buyWithSellerFinancing_collection_offer_reverts_if_limitReached(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 tokenId = offer.collateralItem.tokenId;
        offer.isCollectionOffer = true;

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenId);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenId, buyer1, loanId);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.CollectionOfferLimitReached.selector);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenId + 1,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_collection_offer_reverts_if_limitReached(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_collection_offer_reverts_if_limitReached(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_collection_offer_reverts_if_limitReached() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_collection_offer_reverts_if_limitReached(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_offerSignerNotOwner(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.prank(seller1);
        IERC721Upgradeable(offer.collateralItem.token).safeTransferFrom(
            seller1,
            seller2,
            offer.collateralItem.tokenId
        );

        vm.startPrank(buyer1);
        vm.expectRevert("ERC721: transfer caller is not owner nor approved");
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_offerSignerNotOwner(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_offerSignerNotOwner(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_offerSignerNotOwner() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_offerSignerNotOwner(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_signatureAlreadyUsed(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        vm.warp(loan.periodEndTimestamp + 1);

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.startPrank(seller1);
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SignatureNotAvailable.selector,
                offerSignature
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_signatureAlreadyUsed(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_signatureAlreadyUsed(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_signatureAlreadyUsed() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_signatureAlreadyUsed(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        vm.warp(uint256(offer.expiration) + 1);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.OfferExpired.selector);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_offerExpired(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_offerExpired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_offerExpired(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.loanTerms.periodDuration = 1 minutes - 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.InvalidPeriodDuration.selector);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_invalidPeriodDuration(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_invalidPeriodDuration() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_invalidPeriodDuration(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_invalidDownpaymentValue(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InsufficientMsgValue.selector,
                offer.loanTerms.downPaymentAmount - 1,
                offer.loanTerms.downPaymentAmount
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount - 1 }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_invalidDownpaymentValue(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_invalidDownpaymentValue(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_invalidDownpaymentValue() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_invalidDownpaymentValue(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_withERC20_reverts_if_insufficientDownpaymentValueApproved(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount - 1);
        vm.expectRevert("SafeERC20: low-level call failed");
        sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_withERC20_reverts_if_insufficientDownpaymentValueApproved(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_withERC20_reverts_if_insufficientDownpaymentValueApproved(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withERC20_reverts_if_insufficientDownpaymentValueApproved() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_withERC20_reverts_if_insufficientDownpaymentValueApproved(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_loanItemType721Or1155(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        offer.loanTerms.itemType = ItemType.ERC721;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            INiftyApesErrors.InvalidLoanItemType.selector
        );
        sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        offer.loanTerms.itemType = ItemType.ERC1155;
        bytes memory offerSignature2 = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            INiftyApesErrors.InvalidLoanItemType.selector
        );
        sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature2,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_loanItemType721Or1155(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_loanItemType721Or1155(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_loanItemType721Or1155() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_loanItemType721Or1155(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_principalAmountZero(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.loanTerms.principalAmount = 0;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.PrincipalAmountZero.selector);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_principalAmountZero(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_principalAmountZero(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_principalAmountZero() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_principalAmountZero(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.loanTerms.minimumPrincipalPerPeriod = uint128(offer.loanTerms.principalAmount + 1);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InvalidMinimumPrincipalPerPeriod.selector,
                offer.loanTerms.minimumPrincipalPerPeriod,
                offer.loanTerms.principalAmount
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_invalidMinPrincipalPerPeriod(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_invalidMinPrincipalPerPeriod() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_invalidMinPrincipalPerPeriod(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_buyerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            SANCTIONED_ADDRESS,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_buyerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_buyerSanctioned(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_buyerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_buyerSanctioned(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_callerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_callerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_callerSanctioned(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_callerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_callerSanctioned(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_if_offerForSellerFinancingTicket(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        offer.collateralItem.token = address(sellerFinancing);
        offer.collateralItem.tokenId = loanId + 1;

        bytes memory offerSignature2 = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        vm.expectRevert(INiftyApesErrors.CannotBuySellerFinancingTicket.selector);
        sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature2,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithSellerFinancing_reverts_if_offerForSellerFinancingTicket(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_if_offerForSellerFinancingTicket(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_if_offerForSellerFinancingTicket() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_if_offerForSellerFinancingTicket(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_withMarketplaceFees_ETH(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        offer.marketplaceRecipients = new MarketplaceRecipient[](1);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        bytes memory offerSignature = seller1CreateOffer(offer);

        uint256 marketplaceBalanceBefore = address(SUPERRARE_MARKETPLACE).balance;

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{value: offer.loanTerms.downPaymentAmount + marketplaceFee}(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        uint256 marketplaceBalanceAfter = address(SUPERRARE_MARKETPLACE).balance;

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));
    }

    function test_fuzz_buyWithSellerFinancing_withMarketplaceFees_ETH(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_withMarketplaceFees_ETH(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withMarketplaceFees_ETH() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_withMarketplaceFees_ETH(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_withMarketplaceFees_WETH(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        offer.marketplaceRecipients = new MarketplaceRecipient[](1);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        bytes memory offerSignature = seller1CreateOffer(offer);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = weth.balanceOf(recipients1[0]);
        uint256 marketplaceBalanceBefore = weth.balanceOf(address(SUPERRARE_MARKETPLACE));

        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount + marketplaceFee);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        uint256 marketplaceBalanceAfter = weth.balanceOf(address(SUPERRARE_MARKETPLACE));

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + marketplaceFee));

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);
        uint256 royaltiesBalanceAfter = weth.balanceOf(recipients1[0]);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithSellerFinancing_withMarketplaceFees_WETH(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_withMarketplaceFees_WETH(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withMarketplaceFees_WETH() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_withMarketplaceFees_WETH(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_withTwoMarketplaceRecipients_WETH(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFieldsERC20Payment(fuzzed, defaultFixedOfferFields, WETH_ADDRESS);
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        offer.marketplaceRecipients = new MarketplaceRecipient[](2);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        offer.marketplaceRecipients[1] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        bytes memory offerSignature = seller1CreateOffer(offer);

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.collateralItem.token, offer.collateralItem.tokenId, offer.loanTerms.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 sellerBalanceBefore = weth.balanceOf(seller1);
        uint256 royaltiesBalanceBefore = weth.balanceOf(recipients1[0]);
        uint256 marketplaceBalanceBefore = weth.balanceOf(address(SUPERRARE_MARKETPLACE));

        vm.startPrank(buyer1);
        weth.approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount + 2*marketplaceFee);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        uint256 marketplaceBalanceAfter = weth.balanceOf(address(SUPERRARE_MARKETPLACE));

        assertEq(marketplaceBalanceAfter, (marketplaceBalanceBefore + 2*marketplaceFee));

        uint256 sellerBalanceAfter = weth.balanceOf(seller1);
        uint256 royaltiesBalanceAfter = weth.balanceOf(recipients1[0]);

        // seller paid out correctly
        assertEq(
            sellerBalanceAfter,
            (sellerBalanceBefore + offer.loanTerms.downPaymentAmount - totalRoyaltiesPaid)
        );

        // royatlies paid out correctly
        assertEq(royaltiesBalanceAfter, (royaltiesBalanceBefore + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithSellerFinancing_withTwoMarketplaceRecipients_WETH(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_withTwoMarketplaceRecipients_WETH(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_withTwoMarketplaceRecipients_WETH() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_withTwoMarketplaceRecipients_WETH(fixedForSpeed);
    }

    function _test_buyWithSellerFinancing_reverts_withMarketplaceFees_ifInsufficientPayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 marketplaceFee = ((offer.loanTerms.principalAmount + offer.loanTerms.downPaymentAmount) * SUPERRARE_MARKET_FEE_BPS) / 10_000;

        offer.marketplaceRecipients = new MarketplaceRecipient[](1);
        offer.marketplaceRecipients[0] = MarketplaceRecipient(address(SUPERRARE_MARKETPLACE), marketplaceFee);
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.InsufficientMsgValue.selector,
                offer.loanTerms.downPaymentAmount+marketplaceFee-1,
                offer.loanTerms.downPaymentAmount+marketplaceFee
            )
        );
        sellerFinancing.buyWithSellerFinancing{value: offer.loanTerms.downPaymentAmount + marketplaceFee - 1}(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
        
    }

    function test_fuzz_buyWithSellerFinancing_reverts_withMarketplaceFees_ifInsufficientPayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithSellerFinancing_reverts_withMarketplaceFees_ifInsufficientPayment(fuzzed);
    }

    function test_unit_buyWithSellerFinancing_reverts_withMarketplaceFees_ifInsufficientPayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithSellerFinancing_reverts_withMarketplaceFees_ifInsufficientPayment(fixedForSpeed);
    }
}
