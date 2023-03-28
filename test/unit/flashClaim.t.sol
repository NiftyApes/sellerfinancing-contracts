// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";

import "../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingEvents.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingErrors.sol";

contract TestFlashClaim is Test, ISellerFinancingEvents, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function _test_unit_flashClaim_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        createOfferAndBuyWithFinancing(offer);

        vm.startPrank(buyer1);
        sellerFinancing.flashClaim(
            address(flashClaimReceiverHappy),
            offer.nftContractAddress,
            offer.nftId,
            bytes("")
        );
        vm.stopPrank();

        address nftOwner = IERC721Upgradeable(offer.nftContractAddress).ownerOf(
            offer.nftId
        );

        assertEq(address(sellerFinancing), nftOwner);
    }

    function test_unit_flashClaim_simplest_case() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_unit_flashClaim_simplest_case(fixedForSpeed);
    }

    function _test_unit_cannot_flashClaim_notNftOwner(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        createOfferAndBuyWithFinancing(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        vm.startPrank(buyer2);
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.NotNftOwner.selector, address(sellerFinancing), loan.buyerNftId, buyer2));

        sellerFinancing.flashClaim(
            address(flashClaimReceiverNoReturn),
            offer.nftContractAddress,
            offer.nftId,
            bytes("")
        );
        vm.stopPrank();
    }

    function test_unit_cannot_flashClaim_notNftOwner() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_unit_cannot_flashClaim_notNftOwner(fixedForSpeed);
    }

    function _test_unit_cannot_flashClaim_noReturn(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        createOfferAndBuyWithFinancing(offer);

        vm.startPrank(buyer1);
        vm.expectRevert("ERC721: transfer caller is not owner nor approved");
        sellerFinancing.flashClaim(
            address(flashClaimReceiverNoReturn),
            offer.nftContractAddress,
            offer.nftId,
            bytes("")
        );
        vm.stopPrank();
    }

    function test_unit_cannot_flashClaim_noReturn() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_unit_cannot_flashClaim_noReturn(fixedForSpeed);
    }

    function test_unit_cannot_flashClaim_ReturnsFalse() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        Offer memory offer = offerStructFromFields(
            fixedForSpeed,
            defaultFixedOfferFields
        );
        createOfferAndBuyWithFinancing(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.ExecuteOperationFailed.selector);
        sellerFinancing.flashClaim(
            address(flashClaimReceiverReturnsFalse),
            offer.nftContractAddress,
            offer.nftId,
            bytes("")
        );
        vm.stopPrank();
    }
}
