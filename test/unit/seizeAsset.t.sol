// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

contract TestSeizeAsset is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function _test_seizeAsset_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        vm.warp(loan.periodEndTimestamp + 1);

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.collateralItem.token, offer.collateralItem.identifier, loan);

        vm.startPrank(seller1);
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, seller1, loanId);
    }

    function test_fuzz_seizeAsset_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_simplest_case(fuzzed);
    }

    function test_unit_seizeAsset_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_simplest_case(fixedForSpeed);
    }

    function _test_seizeAsset_reverts_if_not_expired(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);
        
        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.startPrank(seller1);
        vm.expectRevert(INiftyApesErrors.LoanNotInDefault.selector);
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();
    }

    function test_fuzz_seizeAsset_reverts_if_not_expired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_reverts_if_not_expired(fuzzed);
    }

    function test_unit_seizeAsset_reverts_if_not_expired() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_reverts_if_not_expired(fixedForSpeed);
    }

    function _test_seizeAsset_reverts_if_loanClosed(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loanId);

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.loanItem.principalAmount + periodInterest) }(
            loanId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, offer.collateralItem.identifier, buyer1, loanId);

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();
    }

    function test_fuzz_seizeAsset_reverts_if_loanClosed(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_reverts_if_loanClosed(fuzzed);
    }

    function test_unit_seizeAsset_reverts_if_loanClosed() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_reverts_if_loanClosed(fixedForSpeed);
    }

    function _test_seizeAsset_reverts_ifCallerSanctioned(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);
        vm.warp(loan.periodEndTimestamp + 1);

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(seller1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(
            seller1,
            SANCTIONED_ADDRESS,
            loanId + 1
        );

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();
    }

    function test_fuzz_seizeAsset_reverts_ifCallerSanctioned(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_reverts_ifCallerSanctioned(fuzzed);
    }

    function test_unit_seizeAsset_reverts_ifCallerSanctioned() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_reverts_ifCallerSanctioned(fixedForSpeed);
    }

    function _test_seizeAsset_reverts_ifCallerNotSeller(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);
        vm.warp(loan.periodEndTimestamp + 1);

        uint256[] memory loanIds = new uint256[](1);
        loanIds[0] = loanId;

        vm.startPrank(seller2);
        vm.expectRevert(
            abi.encodeWithSelector(INiftyApesErrors.InvalidCaller.selector, seller2, seller1)
        );
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();
    }

    function test_fuzz_seizeAsset_reverts_ifCallerNotSeller(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_reverts_ifCallerNotSeller(fuzzed);
    }

    function test_unit_seizeAsset_reverts_ifCallerNotSeller() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_reverts_ifCallerNotSeller(fixedForSpeed);
    }

    function _test_seizeAsset_with_twoLoans(FuzzedOfferFields memory fuzzed) private {
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
        uint256 loanId1 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanItem.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            nftId1
        );
        uint256 loanId2 = sellerFinancing.buyWithSellerFinancing{ value: offer.loanItem.downPaymentAmount }(
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

        vm.warp(loan1.periodEndTimestamp + 1);

        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = loanId1;
        loanIds[1] = loanId2;

        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.collateralItem.token, nftId1, loan1);
        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.collateralItem.token, nftId2, loan2);

        vm.startPrank(seller1);
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();

        assertionsForClosedLoan(offer.collateralItem.token, nftId1, seller1, loanIds[0]);
        assertionsForClosedLoan(offer.collateralItem.token, nftId2, seller1, loanIds[1]);
    }

    function test_fuzz_seizeAsset_with_twoLoans(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_with_twoLoans(fuzzed);
    }

    function test_unit_seizeAsset_with_twoLoans() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_with_twoLoans(fixedForSpeed);
    }

    function _test_seizeAsset_reverts_if_anyOneSeize_reverts(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.identifier, buyer1, loanId);

        Loan memory loan = sellerFinancing.getLoan(loanId);
        vm.warp(loan.periodEndTimestamp + 1);

        uint256[] memory loanIds = new uint256[](2);
        loanIds[0] = loanId;
        loanIds[1] = 3;

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.seizeAsset(loanIds);
        vm.stopPrank();
    }

    function test_fuzz_seizeAsset_reverts_if_anyOneSeize_reverts(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_seizeAsset_reverts_if_anyOneSeize_reverts(fuzzed);
    }

    function test_unit_seizeAsset_reverts_if_anyOneSeize_reverts() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_seizeAsset_reverts_if_anyOneSeize_reverts(fixedForSpeed);
    }
}
