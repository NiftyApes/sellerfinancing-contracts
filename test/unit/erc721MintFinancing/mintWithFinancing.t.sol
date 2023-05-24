// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestMintWithFinancing is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(SellerFinancingOffer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(erc721MintFinancing.ownerOf(nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(erc721MintFinancing),
                nftId
            ),
            true
        );
        // loan auction exists
        assertEq(
            sellerFinancing.getLoan(address(erc721MintFinancing), nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_mintWithFinancing_simplest_case(FuzzedOfferFields memory fuzzed) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        uint256[] memory tokenIds = erc721MintFinancing.mintWithFinancing{
            value: offer.downPaymentAmount
        }(offer, offerSignature, 1);
        vm.stopPrank();
        assertionsForExecutedLoan(offer, 1);
        assertEq(tokenIds[0], 1);
    }

    function test_fuzz_mintWithFinancing_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_simplest_case(fuzzed);
    }

    function test_unit_mintWithFinancing_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_simplest_case(fixedForSpeed);
    }

    function _test_mintWithFinancing_3_count(FuzzedOfferFields memory fuzzed) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);
        offer.collectionOfferLimit = 3;

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        uint256[] memory tokenIds = erc721MintFinancing.mintWithFinancing{
            value: (offer.downPaymentAmount * offer.collectionOfferLimit)
        }(offer, offerSignature, 3);
        vm.stopPrank();
        assertionsForExecutedLoan(offer, 1);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);
    }

    function test_fuzz_mintWithFinancing_3_count(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_3_count(fuzzed);
    }

    function test_unit_mintWithFinancing_3_count() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_3_count(fixedForSpeed);
    }

    function _test_mintWithFinancing_reverts_ifValueSentLessThanDownpaymentTimesCount(
        FuzzedOfferFields memory fuzzed
    ) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);
        offer.collectionOfferLimit = 3;

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721MintFinancing.InsufficientMsgValue.selector,
                (offer.downPaymentAmount * offer.collectionOfferLimit) - 1,
                (offer.downPaymentAmount * offer.collectionOfferLimit)
            )
        );
        erc721MintFinancing.mintWithFinancing{
            value: (offer.downPaymentAmount * offer.collectionOfferLimit) - 1
        }(offer, offerSignature, 3);
        vm.stopPrank();
    }

    function test_fuzz_mintWithFinancing_reverts_ifValueSentLessThanDownpaymentTimesCount(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_reverts_ifValueSentLessThanDownpaymentTimesCount(fuzzed);
    }

    function test_unit_mintWithFinancing_reverts_ifValueSentLessThanDownpaymentTimesCount() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_reverts_ifValueSentLessThanDownpaymentTimesCount(fixedForSpeed);
    }

    function _test_mintWithFinancing_reverts_ifOfferSignerIsNotOwner(
        FuzzedOfferFields memory fuzzed
    ) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        vm.startPrank(buyer1);

        bytes memory offerSignature = signOffer(buyer1_private_key, offer);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721MintFinancing.InvalidSigner.selector,
                address(buyer1),
                address(seller1)
            )
        );
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            1
        );
        vm.stopPrank();
    }

    function test_fuzz_mintWithFinancing_reverts_ifOfferSignerIsNotOwner(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_reverts_ifOfferSignerIsNotOwner(fuzzed);
    }

    function test_unit_mintWithFinancing_reverts_ifOfferSignerIsNotOwner() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_reverts_ifOfferSignerIsNotOwner(fixedForSpeed);
    }

    function _test_mintWithFinancing_reverts_ifInvalidNftContractAddress(
        FuzzedOfferFields memory fuzzed
    ) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(0);

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721MintFinancing.InvalidNftContractAddress.selector,
                address(0),
                address(erc721MintFinancing)
            )
        );
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            1
        );
        vm.stopPrank();
    }

    function test_fuzz_mintWithFinancing_reverts_ifInvalidNftContractAddress(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_reverts_ifInvalidNftContractAddress(fuzzed);
    }

    function test_unit_mintWithFinancing_reverts_ifInvalidNftContractAddress() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_reverts_ifInvalidNftContractAddress(fixedForSpeed);
    }

    function _test_mintWithFinancing_reverts_ifCountIs0(FuzzedOfferFields memory fuzzed) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(ERC721MintFinancing.CannotMint0.selector));
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            0
        );
        vm.stopPrank();
    }

    function test_fuzz_mintWithFinancing_reverts_ifCountIs0(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_reverts_ifCountIs0(fuzzed);
    }

    function test_unit_mintWithFinancing_reverts_ifCountIs0() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_reverts_ifCountIs0(fixedForSpeed);
    }

    function _test_mintWithFinancing_collectionOfferReachedLimitDuringMint(
        FuzzedOfferFields memory fuzzed
    ) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);
        offer.collectionOfferLimit = 3;

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        uint256 balanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount * 2 }(
            offer,
            offerSignature,
            2
        );
        vm.stopPrank();

        vm.startPrank(buyer1);
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount * 2 }(
            offer,
            offerSignature,
            2
        );
        vm.stopPrank();

        uint256 balanceAfter = address(buyer1).balance;
        uint256 balanceDelta = balanceBefore - balanceAfter;

        // check that correct value has been spent and sent back
        assertEq(balanceDelta, offer.downPaymentAmount * offer.collectionOfferLimit);
    }

    function test_fuzz_mintWithFinancing_collectionOfferReachedLimitDuringMint(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_collectionOfferReachedLimitDuringMint(fuzzed);
    }

    function test_unit_mintWithFinancing_collectionOfferReachedLimitDuringMint() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_collectionOfferReachedLimitDuringMint(fixedForSpeed);
    }

    function _test_mintWithFinancing_collectionOfferLimitAlreadyReached(
        FuzzedOfferFields memory fuzzed
    ) private {
        SellerFinancingOffer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);
        offer.collectionOfferLimit = 0;

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(ERC721MintFinancing.CollectionOfferLimitReached.selector)
        );
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            1
        );
        vm.stopPrank();
    }

    function test_fuzz_mintWithFinancing_collectionOfferLimitAlreadyReached(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_collectionOfferLimitAlreadyReached(fuzzed);
    }

    function test_unit_mintWithFinancing_collectionOfferLimitAlreadyReached() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_collectionOfferLimitAlreadyReached(fixedForSpeed);
    }
}
