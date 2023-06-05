// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";

contract TestSeizeAsset is Test, OffersLoansFixtures, ISellerFinancingEvents {
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
        // loan auction exists
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        assertEq(loan.borrowerNftId, 0);
        assertEq(loan.lenderNftId, 1);
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

    function _test_seizeAsset_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.warp(loan.periodEndTimestamp + 1);

        vm.expectEmit(true, true, false, false);
        emit AssetSeized(offer.nftContractAddress, offer.nftId, loan);

        vm.startPrank(seller1);

        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();

        assertionsForClosedLoan(offer, seller1);
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
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        vm.startPrank(seller1);
        vm.expectRevert(ISellerFinancingErrors.LoanNotInDefault.selector);
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
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
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(loan);

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{ value: (loan.remainingPrincipal + periodInterest) }(
            offer.nftContractAddress,
            offer.nftId
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer1);

        vm.startPrank(seller1);
        vm.expectRevert("ERC721: invalid token ID");
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
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

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        vm.warp(loan.periodEndTimestamp + 1);

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(seller1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(
            seller1,
            SANCTIONED_ADDRESS,
            loan.lenderNftId
        );

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();

        vm.startPrank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISellerFinancingErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
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

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        vm.warp(loan.periodEndTimestamp + 1);

        vm.startPrank(seller2);
        vm.expectRevert(
            abi.encodeWithSelector(ISellerFinancingErrors.InvalidCaller.selector, seller2, seller1)
        );
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
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
}
