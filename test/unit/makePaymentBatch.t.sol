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

    function assertionsForExecutedLoan(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
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
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        // loan exists
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.borrowerNftId), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.lenderNftId), seller1);
        
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function assertionsForClosedLoan(Offer memory offer, uint256 nftId, address expectedNftOwner) private {
        // expected address has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), expectedNftOwner);
        // require delegate.cash buyer delegation has been revoked
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                nftId
            ),
            false
        );
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        // loan doesn't exist anymore
        assertEq(
            loan.periodBeginTimestamp,
            0
        );
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), address(0));
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), address(0));
    }

    function _test_makePaymentBatch_fullRepayment_case_with_oneLoan(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.nftId);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        vm.startPrank(buyer1);
        address[] memory nftContractAddresses = new address[](1);
        nftContractAddresses[0] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.nftId;
        uint256[] memory payments = new uint256[](1);
        payments[0] = (loan.remainingPrincipal + periodInterest);
        sellerFinancing.makePaymentBatch{ value:  payments[0]}(
            nftContractAddresses,
            nftIds,
            payments,
            false
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, offer.nftId, buyer1);
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
        offer.nftId = 0;
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
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1);
        assertionsForExecutedLoan(offer, nftId2);

        Loan memory loan1 = sellerFinancing.getLoan(offer.nftContractAddress, nftId1);
        Loan memory loan2 = sellerFinancing.getLoan(offer.nftContractAddress, nftId2);

        (, uint256 periodInterest1) = sellerFinancing.calculateMinimumPayment(loan1);
        (, uint256 periodInterest2) = sellerFinancing.calculateMinimumPayment(loan2);

        address[] memory nftContractAddresses = new address[](2);
        nftContractAddresses[0] = offer.nftContractAddress;
        nftContractAddresses[1] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId2;
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.remainingPrincipal + periodInterest1);
        payments[1] = (loan2.remainingPrincipal + periodInterest2);

        vm.startPrank(buyer1);
        sellerFinancing.makePaymentBatch{ value:  payments[0]+payments[1]}(
            nftContractAddresses,
            nftIds,
            payments,
            false
        );
        vm.stopPrank();
        assertionsForClosedLoan(offer, nftId1, buyer1);
        assertionsForClosedLoan(offer, nftId2, buyer1);
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

    function _test_makePaymentBatch_returns_anyExtraAmountNotReqToCloseTheLoan(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
       
        createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.nftId);

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
        address[] memory nftContractAddresses = new address[](1);
        nftContractAddresses[0] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = offer.nftId;
        uint256[] memory payments = new uint256[](1);
        payments[0] = (loan.remainingPrincipal + periodInterest);
        sellerFinancing.makePaymentBatch{ value:  (payments[0] + extraAmountToBeSent)}(
            nftContractAddresses,
            nftIds,
            payments,
            false
        );
        vm.stopPrank();
        assertionsForClosedLoan(offer, offer.nftId, buyer1);

        uint256 buyer1BalanceAfterPayment = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfterPayment,
            (buyer1BalanceBeforePayment - (loan.remainingPrincipal + periodInterest))
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
        offer.nftId = 0;
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
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1);
        assertionsForExecutedLoan(offer, nftId2);

        Loan memory loan1 = sellerFinancing.getLoan(offer.nftContractAddress, nftId1);
        Loan memory loan2 = sellerFinancing.getLoan(offer.nftContractAddress, nftId2);

        (, uint256 periodInterest1) = sellerFinancing.calculateMinimumPayment(loan1);
        (, uint256 periodInterest2) = sellerFinancing.calculateMinimumPayment(loan2);

        address[] memory nftContractAddresses = new address[](2);
        nftContractAddresses[0] = offer.nftContractAddress;
        nftContractAddresses[1] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId2;
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.minimumPrincipalPerPeriod + periodInterest1);
        payments[1] = (loan2.minimumPrincipalPerPeriod + periodInterest2);

        vm.startPrank(buyer1);
        sellerFinancing.makePaymentBatch{ value:  payments[0]+payments[1]}(
            nftContractAddresses,
            nftIds,
            payments,
            false
        );
        vm.stopPrank();
        Loan memory loan1_after = sellerFinancing.getLoan(offer.nftContractAddress, nftId1);
        Loan memory loan2_after = sellerFinancing.getLoan(offer.nftContractAddress, nftId2);
        assertEq(loan1_after.remainingPrincipal, loan1.remainingPrincipal - loan1.minimumPrincipalPerPeriod);
        assertEq(loan2_after.remainingPrincipal, loan2.remainingPrincipal - loan1.minimumPrincipalPerPeriod);
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
        offer.nftId = 0;
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
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId2
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer, nftId1);
        assertionsForExecutedLoan(offer, nftId2);

        Loan memory loan1 = sellerFinancing.getLoan(offer.nftContractAddress, nftId1);
        Loan memory loan2 = sellerFinancing.getLoan(offer.nftContractAddress, nftId2);

        (, uint256 periodInterest1) = sellerFinancing.calculateMinimumPayment(loan1);
        (, uint256 periodInterest2) = sellerFinancing.calculateMinimumPayment(loan2);

        address[] memory nftContractAddresses = new address[](2);
        nftContractAddresses[0] = offer.nftContractAddress;
        nftContractAddresses[1] = offer.nftContractAddress;
        uint256[] memory nftIds = new uint256[](2);
        nftIds[0] = nftId1;
        nftIds[1] = nftId2;
        uint256[] memory payments = new uint256[](2);
        payments[0] = (loan1.minimumPrincipalPerPeriod + periodInterest1);
        payments[1] = (loan2.minimumPrincipalPerPeriod + periodInterest2);

        vm.startPrank(buyer1);
        uint256 buyer1BalanceBefore = address(buyer1).balance;
        sellerFinancing.makePaymentBatch{ value:  payments[0] + payments[1] - 1}(
            nftContractAddresses,
            nftIds,
            payments,
            true
        );
        vm.stopPrank();
        Loan memory loan1_after = sellerFinancing.getLoan(offer.nftContractAddress, nftId1);
        Loan memory loan2_after = sellerFinancing.getLoan(offer.nftContractAddress, nftId2);
        assertEq(loan1_after.remainingPrincipal, loan1.remainingPrincipal - loan1.minimumPrincipalPerPeriod);
        assertEq(loan2_after.remainingPrincipal, loan2.remainingPrincipal);
        
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
