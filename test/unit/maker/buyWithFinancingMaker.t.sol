// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "../../utils/fixtures/OffersLoansFixtures.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../../src/interfaces/seaport/ISeaport.sol";

contract TestBuyWithFinancingMaker is Test, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedMakerLoan(Offer memory offer) private {
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
        // seller NFT minted to maker
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(1),
            address(maker)
        );

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );
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

    function _test_buyWithFinancingMaker_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        ISeaport.Order memory order = createAndValidatePurchaseOrderFromSeller2();
        Offer memory offer = offerStructFromSeaportOrder(
            order,
            fuzzed
        );
        bytes memory offerSignature = signOffer(seller1_private_key, offer);

        vm.deal(address(maker), defaultInitialEthBalance);
        vm.startPrank(buyer1);
        maker.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1,
            address(seaportExecuter),
            abi.encode(order, bytes32(0))
        );
        vm.stopPrank();
        assertionsForExecutedMakerLoan(offer);
    }

    // function test_fuzz_buyWithFinancing_simplest_case(
    //     FuzzedOfferFields memory fuzzed
    // ) public validateFuzzedOfferFields(fuzzed) {
    //     _test_buyWithFinancing_simplest_case(fuzzed);
    // }

    function test_unit_buyWithFinancingMaker_simplest_case() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_buyWithFinancingMaker_simplest_case(fixedForSpeed);
    }

    function createAndValidatePurchaseOrderFromSeller2() internal returns (ISeaport.Order memory) {
        ISeaport.Order memory order;
        order.parameters.offerer = seller2;
        order.parameters.zone = address(0x004C00500000aD104D7DBd00e3ae0A5C00560C00);
        order.parameters.offer = new ISeaport.OfferItem[](1);
        order.parameters.offer[0].itemType = ISeaport.ItemType.ERC721;
        order.parameters.offer[0].token = address(boredApeYachtClub);
        order.parameters.offer[0].identifierOrCriteria = 6974;
        order.parameters.offer[0].startAmount = 1;
        order.parameters.offer[0].endAmount = 1;
        order.parameters.consideration = new ISeaport.ConsiderationItem[](3);
        order.parameters.consideration[0].itemType = ISeaport.ItemType.NATIVE;
        order.parameters.consideration[0].token = address(0);
        order.parameters.consideration[0].identifierOrCriteria = 0;
        order.parameters.consideration[0].startAmount = 73625000000000000000;
        order.parameters.consideration[0].endAmount = 73625000000000000000;
        order.parameters.consideration[0].recipient = seller2;
        order.parameters.consideration[1].itemType = ISeaport.ItemType.NATIVE;
        order.parameters.consideration[1].token = address(0);
        order.parameters.consideration[1].identifierOrCriteria = 0;
        order.parameters.consideration[1].startAmount = 1937500000000000000;
        order.parameters.consideration[1].endAmount = 1937500000000000000;
        order.parameters.consideration[1].recipient = payable(
            address(0x0000a26b00c1F0DF003000390027140000fAa719)
        );
        order.parameters.consideration[2].itemType = ISeaport.ItemType.NATIVE;
        order.parameters.consideration[2].token = address(0);
        order.parameters.consideration[2].identifierOrCriteria = 0;
        order.parameters.consideration[2].startAmount = 1937500000000000000;
        order.parameters.consideration[2].endAmount = 1937500000000000000;
        order.parameters.consideration[2].recipient = payable(
            address(0xA858DDc0445d8131daC4d1DE01f834ffcbA52Ef1)
        );
        order.parameters.orderType = ISeaport.OrderType.FULL_RESTRICTED;
        order.parameters.startTime = block.timestamp;
        order.parameters.endTime = block.timestamp + 24 hours;
        order.parameters.zoneHash = bytes32(
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        order.parameters.salt = 96789058676732069;
        order.parameters.conduitKey = bytes32(
            0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000
        );
        order.parameters.totalOriginalConsiderationItems = 3;
        order.signature = bytes("");

        ISeaport.Order[] memory orders = new ISeaport.Order[](1);
        orders[0] = order;
        vm.startPrank(seller2);
        ISeaport(SEAPORT_ADDRESS).validate(orders);
        boredApeYachtClub.approve(SEAPORT_CONDUIT, order.parameters.offer[0].identifierOrCriteria);
        vm.stopPrank();
        return order;
    }

    function offerStructFromSeaportOrder(
        ISeaport.Order memory order,
        FuzzedOfferFields memory fuzzed
    ) internal view returns (Offer memory) {
        uint128 considerationAmount;
        for (uint256 i = 0; i < order.parameters.totalOriginalConsiderationItems; i++) {
            considerationAmount += uint128(order.parameters.consideration[i].endAmount);
        }
        return
            Offer({
                creator: address(maker),
                nftId: order.parameters.offer[0].identifierOrCriteria,
                nftContractAddress: order.parameters.offer[0].token,
                price: considerationAmount,
                downPaymentAmount: considerationAmount / 5,
                minimumPrincipalPerPeriod: considerationAmount / 5,
                periodInterestRateBps: fuzzed.periodInterestRateBps,
                periodDuration: fuzzed.periodDuration,
                expiration: fuzzed.expiration
            });
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
