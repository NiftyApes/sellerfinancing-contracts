// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingErrors.sol";

contract TestBuyWithFinancing is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(
            boredApeYachtClub.ownerOf(offer.nftId),
            address(sellerFinancing)
        );
        // balance increments to one
        assertEq(
            sellerFinancing.balanceOf(buyer1, address(boredApeYachtClub)),
            1
        );
        // nftId exists at index 0
        assertEq(
            sellerFinancing.tokenOfOwnerByIndex(
                buyer1,
                address(boredApeYachtClub),
                0
            ),
            offer.nftId
        );
        // loan auction exists
        assertEq(
            sellerFinancing
                .getLoan(address(boredApeYachtClub), offer.nftId)
                .periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(0),
            buyer1
        );
        // seller NFT minted to seller
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(1),
            seller1
        );

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(offer.nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId));
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(
            loan.remainingPrincipal,
            offer.price - offer.downPaymentAmount
        );
        assertEq(
            loan.minimumPrincipalPerPeriod,
            offer.minimumPrincipalPerPeriod
        );
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(
            loan.periodEndTimestamp,
            block.timestamp + offer.periodDuration
        );
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWithFinancing_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);
    }

    function test_fuzz_buyWithFinancing_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_simplest_case(fuzzed);
    }

    function test_unit_buyWithFinancing_simplest_case() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_simplest_case(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_offerSignerNotOwner(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.prank(seller1);
        IERC721Upgradeable(offer.nftContractAddress).safeTransferFrom(seller1, seller2, offer.nftId);
        
        vm.startPrank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.NotNftOwner.selector, offer.nftContractAddress, offer.nftId, seller1));
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_offerSignerNotOwner(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_offerSignerNotOwner(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_offerSignerNotOwner() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_offerSignerNotOwner(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_signatureAlreadyUsed(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        vm.warp(loan.periodEndTimestamp + 1);

        vm.startPrank(seller1);
        sellerFinancing.seizeAsset(offer.nftContractAddress, offer.nftId);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.SignatureNotAvailable.selector, offerSignature));
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_signatureAlreadyUsed(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_signatureAlreadyUsed(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_signatureAlreadyUsed() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_signatureAlreadyUsed(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);
        vm.assume(fuzzed.expiration < type(uint32).max - 1);
        vm.warp(uint256(offer.expiration) + 1);

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.OfferExpired.selector);
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_offerExpired(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_offerExpired(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_offerExpired() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_offerExpired(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        offer.periodDuration = 1 minutes - 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(ISellerFinancingErrors.InvalidPeriodDuration.selector);
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_invalidPeriodDuration(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_invalidPeriodDuration(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_invalidPeriodDuration() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_invalidPeriodDuration(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_invalidDownpaymentValue(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.InsufficientMsgValue.selector, offer.downPaymentAmount - 1, offer.downPaymentAmount));
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount - 1}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_invalidDownpaymentValue(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_invalidDownpaymentValue(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_invalidDownpaymentValue() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_invalidDownpaymentValue(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        offer.price = offer.downPaymentAmount - 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.DownPaymentGreaterThanOrEqualToOfferPrice.selector, offer.downPaymentAmount, offer.price));
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_offerPriceLessThanDownpayment(fixedForSpeed);
    }

    function _test_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );
        offer.minimumPrincipalPerPeriod = (offer.price - offer.downPaymentAmount) + 1;
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        vm.expectRevert(abi.encodeWithSelector(ISellerFinancingErrors.InvalidMinimumPrincipalPerPeriod.selector, offer.minimumPrincipalPerPeriod, offer.price - offer.downPaymentAmount));
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1
        );
        vm.stopPrank();
    }

    function test_fuzz_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(fuzzed);
    }

    function test_unit_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancing_reverts_if_invalidMinPrincipalPerPeriod(fixedForSpeed);
    }


    // function _test_buyWithFinancing_events(FuzzedOfferFields memory fuzzed)
    //     private
    // {
    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );

    //     Loan memory loan = sellerFinancing.getLoan(
    //         offer.nftContractAddress,
    //         offer.nftId
    //     );

    //     vm.expectEmit(true, true, false, false);
    //     emit LoanExecuted(offer.nftContractAddress, offer.nftId, loan);

    //     createOfferAndTryTobuyWithFinancing(offer, "should work");
    // }

    // function test_unit_buyWithFinancing_events() public {
    //     _test_buyWithFinancing_events(
    //         defaultFixedFuzzedFieldsForFastUnitTesting
    //     );
    // }

    // function test_fuzz_buyWithFinancing_events(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_buyWithFinancing_events(fuzzed);
    // }

    // function _test_cannot_buyWithFinancing_if_offer_expired(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );
    //     createOffer(offer, seller1);
    //     vm.warp(offer.expiration);
    //     approvesellerFinancing(offer);
    //     tryTobuyWithFinancing(offer, "00010");
    // }

    // function test_fuzz_cannot_buyWithFinancing_if_offer_expired(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_cannot_buyWithFinancing_if_offer_expired(fuzzed);
    // }

    // function test_unit_cannot_buyWithFinancing_if_offer_expired() public {
    //     _test_cannot_buyWithFinancing_if_offer_expired(
    //         defaultFixedFuzzedFieldsForFastUnitTesting
    //     );
    // }

    // function _test_cannot_buyWithFinancing_if_dont_own_nft(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );
    //     createOffer(offer, seller1);
    //     approvesellerFinancing(offer);
    //     vm.startPrank(buyer1);
    //     boredApeYachtClub.safeTransferFrom(buyer1, buyer2, 1);
    //     vm.stopPrank();
    //     tryTobuyWithFinancing(offer, "00021");
    // }

    // function test_fuzz_cannot_buyWithFinancing_if_dont_own_nft(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_cannot_buyWithFinancing_if_dont_own_nft(fuzzed);
    // }

    // function test_unit_cannot_buyWithFinancing_if_dont_own_nft() public {
    //     _test_cannot_buyWithFinancing_if_dont_own_nft(
    //         defaultFixedFuzzedFieldsForFastUnitTesting
    //     );
    // }

    // function _test_cannot_buyWithFinancing_if_loan_active(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     defaultFixedOfferFields.sellerOffer = true;
    //     fuzzed.floorTerm = true;

    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );
    //     offer.floorTermLimit = 2;

    //     createOffer(offer, seller1);

    //     approvesellerFinancing(offer);
    //     tryTobuyWithFinancing(offer, "should work");

    //     tryTobuyWithFinancing(offer, "00006");
    // }

    // function test_fuzz_buyWithFinancing_if_loan_active(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_cannot_buyWithFinancing_if_loan_active(fuzzed);
    // }

    // function test_unit_buyWithFinancing_if_loan_active() public {
    //     _test_cannot_buyWithFinancing_if_loan_active(
    //         defaultFixedFuzzedFieldsForFastUnitTesting
    //     );
    // }

    // function _test_cannot_buyWithFinancing_sanctioned_address_borrower(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     defaultFixedOfferFields.sellerOffer = true;
    //     defaultFixedOfferFields.nftId = 3;

    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );

    //     createOffer(offer, seller1);

    //     bytes32 offerHash = offers.getOfferHash(offer);

    //     vm.startPrank(SANCTIONED_ADDRESS);
    //     boredApeYachtClub.approve(address(sellerFinancing), 3);

    //     vm.expectRevert("00017");
    //     sellerFinancing.buyWithFinancing(offer.nftId, offerHash);
    //     vm.stopPrank();
    // }

    // function test_fuzz_buyWithFinancing_sanctioned_address_borrower(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_cannot_buyWithFinancing_sanctioned_address_borrower(fuzzed);
    // }

    // function test_unit_buyWithFinancing_sanctioned_address_borrower()
    //     public
    // {
    //     _test_cannot_buyWithFinancing_sanctioned_address_borrower(
    //         defaultFixedFuzzedFieldsForFastUnitTesting
    //     );
    // }

    // function _test_cannot_buyWithFinancing_sanctioned_address_seller(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     vm.startPrank(owner);
    //     liquidity.pauseSanctions();
    //     vm.stopPrank();

    //     fuzzed.randomAsset = 0;

    //     if (integration) {
    //         vm.startPrank(daiWhale);
    //         daiToken.transfer(
    //             SANCTIONED_ADDRESS,
    //             defaultDaiLiquiditySupplied / 2
    //         );
    //         vm.stopPrank();
    //     } else {
    //         vm.startPrank(SANCTIONED_ADDRESS);
    //         daiToken.mint(SANCTIONED_ADDRESS, defaultDaiLiquiditySupplied / 2);
    //         vm.stopPrank();
    //     }

    //     vm.startPrank(SANCTIONED_ADDRESS);
    //     daiToken.approve(address(liquidity), defaultDaiLiquiditySupplied / 2);

    //     liquidity.supplyErc20(
    //         address(daiToken),
    //         defaultDaiLiquiditySupplied / 2
    //     );
    //     vm.stopPrank();

    //     defaultFixedOfferFields.sellerOffer = true;

    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );

    //     createOffer(offer, SANCTIONED_ADDRESS);

    //     vm.startPrank(owner);
    //     liquidity.unpauseSanctions();
    //     vm.stopPrank();

    //     bytes32 offerHash = offers.getOfferHash(offer);

    //     vm.startPrank(buyer1);
    //     boredApeYachtClub.approve(address(sellerFinancing), 1);

    //     vm.expectRevert("00017");
    //     sellerFinancing.buyWithFinancing(offer.nftId, offerHash);
    //     vm.stopPrank();
    // }

    // function test_fuzz_buyWithFinancing_sanctioned_address_seller(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_cannot_buyWithFinancing_sanctioned_address_seller(fuzzed);
    // }

    // function test_unit_buyWithFinancing_sanctioned_address_seller()
    //     public
    // {
    //     _test_cannot_buyWithFinancing_sanctioned_address_seller(
    //         defaultFixedFuzzedFieldsForFastUnitTesting
    //     );
    // }
}
