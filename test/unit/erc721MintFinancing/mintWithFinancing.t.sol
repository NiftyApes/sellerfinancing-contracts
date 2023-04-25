// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestMintWithFinancing is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(erc721MintFinancing.ownerOf(offer.nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(erc721MintFinancing),
                offer.nftId
            ),
            true
        );
        // loan auction exists
        assertEq(
            sellerFinancing.getLoan(address(erc721MintFinancing), offer.nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
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
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);

        vm.startPrank(seller1);
        erc721MintFinancing.setApprovalForAll(address(sellerFinancing), true);
        vm.stopPrank();

        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer);

        // assert newly minted nftId == 0
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

    function _test_mintWithFinancing_reverts_ifValueSentLessThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(fuzzed, defaultFixedOfferFields);
        offer.nftId = ~uint256(0);
        offer.nftContractAddress = address(erc721MintFinancing);

        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721MintFinancing.InsufficientMsgValue.selector,
                offer.downPaymentAmount - 1,
                offer.downPaymentAmount
            )
        );
        erc721MintFinancing.mintWithFinancing{ value: offer.downPaymentAmount - 1 }(
            offer,
            offerSignature
        );
        vm.stopPrank();
    }

    function test_fuzz_mintWithFinancing_reverts_ifValueSentLessThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_mintWithFinancing_reverts_ifValueSentLessThanDownpayment(fuzzed);
    }

    function test_unit_mintWithFinancing_reverts_ifValueSentLessThanDownpayment() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_mintWithFinancing_reverts_ifValueSentLessThanDownpayment(fixedForSpeed);
    }
}
