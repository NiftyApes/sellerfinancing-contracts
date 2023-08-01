// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../../src/interfaces/seaport/ISeaport.sol";
import "../../../src/interfaces/niftyapes/INiftyApesEvents.sol";
import "../../common/Console.sol";

contract TestInstantSellBatch is Test, OffersLoansFixtures, INiftyApesEvents {
    uint256[] tokenIds = new uint256[](2);
        
    function setUp() public override {
        super.setUp();
        tokenIds[0] = 8661;
        tokenIds[1] = 6974;
    }

    function _test_instantSellBatch_simplest_one_loan_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanIds[0]);

        Loan memory loan = sellerFinancing.getLoan(loanIds[0]);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);

        

        uint256[] memory minProfitAmounts = new uint256[](1);
        minProfitAmounts[0] = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanTerms.principalAmount + periodInterest + minProfitAmounts[0]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            offer.collateralItem.tokenId,
            bidPrice,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encode(order[0]);

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loanIds[0]);
        
        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, offer.collateralItem.tokenId, 0);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            false
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.tokenId, buyer2, 0);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore - offer.loanTerms.downPaymentAmount + minProfitAmounts[0])
        );
    }

    function test_fuzz_instantSellBatch_simplest_one_loan_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_simplest_one_loan_case(fuzzed);
    }

    function test_unit_instantSellBatch_simplest_one_loan_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_simplest_one_loan_case(fixedForSpeed);
    }

    function _test_instantSellBatch_executes_two_loan_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[0],
            offer.collateralItem.amount
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[1],
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        Loan memory loan0 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan1 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterestLoan0,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);
        (, uint256 periodInterestLoan1,) = sellerFinancing.calculateMinimumPayment(loanIds[1]);

        uint256[] memory minProfitAmounts = new uint256[](2);
        minProfitAmounts[0] = 1 ether;
        minProfitAmounts[1] = 2 ether;

        uint256 expectedBuyer1BalanceAfterLoanIsClosed = (buyer1BalanceBefore - 2 * offer.loanTerms.downPaymentAmount + minProfitAmounts[0] + minProfitAmounts[1]);

        // adding 2.5% opnesea fee amount
        uint256 bidPriceLoan0 = ((loan0.loanTerms.principalAmount + periodInterestLoan0 + minProfitAmounts[0]) *
            40 +
            38) / 39;
        uint256 bidPriceLoan1 = ((loan1.loanTerms.principalAmount + periodInterestLoan1 + minProfitAmounts[1]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory orderForClosingLoan0 = _createOrder(
            offer.collateralItem.token,
            tokenIds[0],
            bidPriceLoan0,
            buyer2,
            true
        );
        ISeaport.Order[] memory orderForClosingLoan1 = _createOrder(
            offer.collateralItem.token,
            tokenIds[1],
            bidPriceLoan1,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPriceLoan0 + bidPriceLoan1);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPriceLoan0 + bidPriceLoan1);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan0);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan1);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(orderForClosingLoan0[0]);
        data[1] = abi.encode(orderForClosingLoan1[0]);

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan0.loanId);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan1.loanId);
        
        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, tokenIds[0], 0);
        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, tokenIds[1], 0);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            false
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, tokenIds[0], buyer2, loan0.loanId);
        assertionsForClosedLoan(offer.collateralItem.token,  tokenIds[1], buyer2, loan1.loanId);
        assertEq(
            address(buyer1).balance,
            expectedBuyer1BalanceAfterLoanIsClosed
        );
    }

    function test_fuzz_instantSellBatch_executes_two_loan_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_executes_two_loan_case(fuzzed);
    }

    function test_unit_instantSellBatch_executes_two_loan_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_executes_two_loan_case(fixedForSpeed);
    }

    function _test_instantSellBatch_partialExecution_doesnt_revert_if_firstBuyerTicketsTransferFails(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[0],
            offer.collateralItem.amount
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[1],
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        Loan memory loan0 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan1 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterestLoan0,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);
        (, uint256 periodInterestLoan1,) = sellerFinancing.calculateMinimumPayment(loanIds[1]);

        uint256[] memory minProfitAmounts = new uint256[](2);
        minProfitAmounts[0] = 1 ether;
        minProfitAmounts[1] = 2 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPriceLoan0 = ((loan0.loanTerms.principalAmount + periodInterestLoan0 + minProfitAmounts[0]) *
            40 +
            38) / 39;
        uint256 bidPriceLoan1 = ((loan1.loanTerms.principalAmount + periodInterestLoan1 + minProfitAmounts[1]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory orderForClosingLoan0 = _createOrder(
            offer.collateralItem.token,
            tokenIds[0],
            bidPriceLoan0,
            buyer2,
            true
        );
        ISeaport.Order[] memory orderForClosingLoan1 = _createOrder(
            offer.collateralItem.token,
            tokenIds[1],
            bidPriceLoan1,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPriceLoan0 + bidPriceLoan1);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPriceLoan0 + bidPriceLoan1);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan0);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan1);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(orderForClosingLoan0[0]);
        data[1] = abi.encode(orderForClosingLoan1[0]);

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan1.loanId);        
        // not approving loan0 buyer ticket and expecting the call to not fail and only execute second transaction
        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, tokenIds[1], 0);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            true
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token,  tokenIds[1], buyer2, loan1.loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore + minProfitAmounts[1])
        );

        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), address(sellerFinancing));
        // buyer1 still owns loan0.loanId
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan0.loanId), address(buyer1));
    }

    function test_fuzz_instantSellBatch_partialExecution_doesnt_revert_if_firstBuyerTicketsTransferFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_partialExecution_doesnt_revert_if_firstBuyerTicketsTransferFails(fuzzed);
    }

    function test_unit_instantSellBatch_partialExecution_doesnt_revert_if_firstBuyerTicketsTransferFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_partialExecution_doesnt_revert_if_firstBuyerTicketsTransferFails(fixedForSpeed);
    }

    function _test_instantSellBatch_partialExecution_doesnt_revert_if_lastBuyerTicketsTransferFails(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        
        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[0],
            offer.collateralItem.amount
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[1],
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        Loan memory loan0 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan1 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterestLoan0,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);
        (, uint256 periodInterestLoan1,) = sellerFinancing.calculateMinimumPayment(loanIds[1]);

        

        uint256[] memory minProfitAmounts = new uint256[](2);
        minProfitAmounts[0] = 1 ether;
        minProfitAmounts[1] = 2 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPriceLoan0 = ((loan0.loanTerms.principalAmount + periodInterestLoan0 + minProfitAmounts[0]) *
            40 +
            38) / 39;
        uint256 bidPriceLoan1 = ((loan1.loanTerms.principalAmount + periodInterestLoan1 + minProfitAmounts[1]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory orderForClosingLoan0 = _createOrder(
            offer.collateralItem.token,
            tokenIds[0],
            bidPriceLoan0,
            buyer2,
            true
        );
        ISeaport.Order[] memory orderForClosingLoan1 = _createOrder(
            offer.collateralItem.token,
            tokenIds[1],
            bidPriceLoan1,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPriceLoan0 + bidPriceLoan1);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPriceLoan0 + bidPriceLoan1);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan0);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan1);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(orderForClosingLoan0[0]);
        data[1] = abi.encode(orderForClosingLoan1[0]);

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan0.loanId);        
        // not approving loan1 buyer ticket and expecting the call to not fail and only execute first transaction
        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, tokenIds[0], 0);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            true
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token,  tokenIds[0], buyer2, loan0.loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore + minProfitAmounts[0])
        );

        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(sellerFinancing));
        // buyer1 still owns loan1.loanId
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan1.loanId), address(buyer1));
    }

    function test_fuzz_instantSellBatch_partialExecution_doesnt_revert_if_lastBuyerTicketsTransferFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_partialExecution_doesnt_revert_if_lastBuyerTicketsTransferFails(fuzzed);
    }

    function test_unit_instantSellBatch_partialExecution_doesnt_revert_if_lastBuyerTicketsTransferFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_partialExecution_doesnt_revert_if_lastBuyerTicketsTransferFails(fixedForSpeed);
    }

    function _test_instantSellBatch_partialExecution_doesnt_revert_if_lastInstantSellFails(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        
        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[0],
            offer.collateralItem.amount
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[1],
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        Loan memory loan0 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan1 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterestLoan0,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);

        uint256[] memory minProfitAmounts = new uint256[](2);
        minProfitAmounts[0] = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPriceLoan0 = ((loan0.loanTerms.principalAmount + periodInterestLoan0 + minProfitAmounts[0]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory orderForClosingLoan0 = _createOrder(
            offer.collateralItem.token,
            tokenIds[0],
            bidPriceLoan0,
            buyer2,
            true
        );
    
        mintWeth(buyer2, bidPriceLoan0);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPriceLoan0);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan0);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(orderForClosingLoan0[0]);
        // setting the second seaport order to the first order which would cause the second instantSell to fail
        data[1] = abi.encode(orderForClosingLoan0[0]);

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan0.loanId);  
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan1.loanId);        

        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, tokenIds[0], 0);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            true
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token,  tokenIds[0], buyer2, loan0.loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore + minProfitAmounts[0])
        );

        assertEq(boredApeYachtClub.ownerOf(tokenIds[1]), address(sellerFinancing));
        // buyer1 still owns loan1.loanId
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan1.loanId), address(buyer1));
    }

    function test_fuzz_instantSellBatch_partialExecution_doesnt_revert_if_lastInstantSellFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_partialExecution_doesnt_revert_if_lastInstantSellFails(fuzzed);
    }

    function test_unit_instantSellBatch_partialExecution_doesnt_revert_if_lastInstantSellFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_partialExecution_doesnt_revert_if_lastInstantSellFails(fixedForSpeed);
    }

     function _test_instantSellBatch_partialExecution_doesnt_revert_if_firstInstantSellFails(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        
        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[0],
            offer.collateralItem.amount
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[1],
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        Loan memory loan0 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan1 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterestLoan1,) = sellerFinancing.calculateMinimumPayment(loanIds[1]);

        

        uint256[] memory minProfitAmounts = new uint256[](2);
        minProfitAmounts[1] = 2 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPriceLoan1 = ((loan1.loanTerms.principalAmount + periodInterestLoan1 + minProfitAmounts[1]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory orderForClosingLoan1 = _createOrder(
            offer.collateralItem.token,
            tokenIds[1],
            bidPriceLoan1,
            buyer2,
            true
        );
    
        mintWeth(buyer2, bidPriceLoan1);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPriceLoan1);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan1);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        // setting the second seaport order to the first order which would cause the first instantSell to fail
        data[0] = abi.encode(orderForClosingLoan1[0]);
        data[1] = abi.encode(orderForClosingLoan1[0]);

        uint256 buyer1BalanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan0.loanId);  
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan1.loanId);        

        vm.expectEmit(true, true, false, false);
        emit InstantSell(offer.collateralItem.token, tokenIds[1], 0);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            true
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token,  tokenIds[1], buyer2, loan1.loanId);
        assertEq(
            address(buyer1).balance,
            (buyer1BalanceBefore + minProfitAmounts[1])
        );

        assertEq(boredApeYachtClub.ownerOf(tokenIds[0]), address(sellerFinancing));
        // buyer1 still owns loan0.loanId
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan0.loanId), address(buyer1));
    }

    function test_fuzz_instantSellBatch_partialExecution_doesnt_revert_if_firstInstantSellFails(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_partialExecution_doesnt_revert_if_firstInstantSellFails(fuzzed);
    }

    function test_unit_instantSellBatch_partialExecution_doesnt_revert_if_firstInstantSellFails() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_partialExecution_doesnt_revert_if_firstInstantSellFails(fixedForSpeed);
    }

    function _test_instantSellBatch_reverts_if_buyerTicketsNotApprovedForMarketplace(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.isCollectionOffer = true;
        offer.collectionOfferLimit = 2;

        bytes memory offerSignature =  signOffer(seller1_private_key, offer);

        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller1 , 6974);

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), 8661);
        boredApeYachtClub.approve(address(sellerFinancing), 6974);
        vm.stopPrank();

        
        vm.startPrank(buyer1);
        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[0],
            offer.collateralItem.amount
        );
        loanIds[1] = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            tokenIds[1],
            offer.collateralItem.amount
        );
        vm.stopPrank();

        assertionsForExecutedLoan(offer, tokenIds[0], buyer1, loanIds[0]);
        assertionsForExecutedLoan(offer, tokenIds[1], buyer1, loanIds[1]);

        Loan memory loan0 = sellerFinancing.getLoan(loanIds[0]);
        Loan memory loan1 = sellerFinancing.getLoan(loanIds[1]);

        (, uint256 periodInterestLoan0,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);
        (, uint256 periodInterestLoan1,) = sellerFinancing.calculateMinimumPayment(loanIds[1]);

        

        uint256[] memory minProfitAmounts = new uint256[](2);
        minProfitAmounts[0] = 1 ether;
        minProfitAmounts[1] = 2 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPriceLoan0 = ((loan0.loanTerms.principalAmount + periodInterestLoan0 + minProfitAmounts[0]) *
            40 +
            38) / 39;
        uint256 bidPriceLoan1 = ((loan1.loanTerms.principalAmount + periodInterestLoan1 + minProfitAmounts[1]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory orderForClosingLoan0 = _createOrder(
            offer.collateralItem.token,
            tokenIds[0],
            bidPriceLoan0,
            buyer2,
            true
        );
        ISeaport.Order[] memory orderForClosingLoan1 = _createOrder(
            offer.collateralItem.token,
            tokenIds[1],
            bidPriceLoan1,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPriceLoan0 + bidPriceLoan1);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPriceLoan0 + bidPriceLoan1);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan0);
        ISeaport(SEAPORT_ADDRESS).validate(orderForClosingLoan1);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(orderForClosingLoan0[0]);
        data[1] = abi.encode(orderForClosingLoan1[0]);

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loan0.loanId);        
        // not approving loan1 buyer ticket and expecting the call to fail
    
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketplaceIntegration.BuyerTicketTransferRevertedAt.selector,
                1,
                buyer1,
                address(marketplaceIntegration)
            )
        );
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSellBatch_reverts_if_buyerTicketsNotApprovedForMarketplace(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_reverts_if_buyerTicketsNotApprovedForMarketplace(fuzzed);
    }

    function test_unit_instantSellBatch_reverts_if_buyerTicketsNotApprovedForMarketplace() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_reverts_if_buyerTicketsNotApprovedForMarketplace(fixedForSpeed);
    }

    function _test_instantSellBatch_reverts_if_invalidInputLengths(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanIds[0]);

        Loan memory loan = sellerFinancing.getLoan(loanIds[0]);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(loanIds[0]);

        

        uint256[] memory minProfitAmounts = new uint256[](1);
        minProfitAmounts[0] = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.loanTerms.principalAmount + periodInterest + minProfitAmounts[0]) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.collateralItem.token,
            tokenIds[0],
            bidPrice,
            buyer2,
            true
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(order[0]);
        data[1] = abi.encode(order[0]);

        vm.startPrank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).approve(address(marketplaceIntegration), loanIds[0]);
        vm.expectRevert(MarketplaceIntegration.InvalidInputLength.selector);
        marketplaceIntegration.instantSellBatch(
            loanIds,
            minProfitAmounts,
            data,
            false
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSellBatch_reverts_if_invalidInputLengths(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSellBatch_reverts_if_invalidInputLengths(fuzzed);
    }

    function test_unit_instantSellBatch_reverts_if_invalidInputLengths() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSellBatch_reverts_if_invalidInputLengths(fixedForSpeed);
    }

    function _createOrder(
        address tokenContractAddress,
        uint256 tokenId,
        uint256 bidPrice,
        address orderCreator,
        bool addSeaportFee
    ) internal view returns (ISeaport.Order[] memory order) {
        uint256 seaportFeeAmount;
        uint256 totalOriginalConsiderationItems = 1;
        if (addSeaportFee) {
            seaportFeeAmount = bidPrice - (bidPrice * 39) / 40;
            totalOriginalConsiderationItems = 2;
        }

        ISeaport.ItemType offerItemType = ISeaport.ItemType.ERC20;
        address offerToken = WETH_ADDRESS;

        order = new ISeaport.Order[](1);
        order[0] = ISeaport.Order({
            parameters: ISeaport.OrderParameters({
                offerer: payable(orderCreator),
                zone: address(0),
                offer: new ISeaport.OfferItem[](1),
                consideration: new ISeaport.ConsiderationItem[](totalOriginalConsiderationItems),
                orderType: ISeaport.OrderType.FULL_OPEN,
                startTime: block.timestamp,
                endTime: block.timestamp + 24 * 60 * 60,
                zoneHash: bytes32(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                ),
                salt: 1,
                conduitKey: bytes32(
                    0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
                ),
                totalOriginalConsiderationItems: totalOriginalConsiderationItems
            }),
            signature: bytes("")
        });
        order[0].parameters.offer[0] = ISeaport.OfferItem({
            itemType: offerItemType,
            token: offerToken,
            identifierOrCriteria: 0,
            startAmount: bidPrice,
            endAmount: bidPrice
        });
        order[0].parameters.consideration[0] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.ERC721,
            token: tokenContractAddress,
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(orderCreator)
        });
        if (totalOriginalConsiderationItems > 1) {
            order[0].parameters.consideration[1] = ISeaport.ConsiderationItem({
                itemType: offerItemType,
                token: offerToken,
                identifierOrCriteria: 0,
                startAmount: seaportFeeAmount,
                endAmount: seaportFeeAmount,
                recipient: payable(0x0000a26b00c1F0DF003000390027140000fAa719)
            });
        }
    }
}
