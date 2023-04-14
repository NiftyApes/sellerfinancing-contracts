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

    function assertionsForExecutedMakerLoan(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
        // loan auction exists
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
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), address(maker));

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );
        Console.log(IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.buyerNftId));

        // check loan struct values
        assertEq(loan.buyerNftId, 0);
        assertEq(loan.sellerNftId, 1);
        assertEq(loan.remainingPrincipal, offer.price - offer.downPaymentAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
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
        uint256 makerBalanceBefore = address(maker).balance;

        (address payable[] memory recipients1, uint256[] memory amounts1) = IRoyaltyEngineV1(
            0x0385603ab55642cb4Dd5De3aE9e306809991804f
        ).getRoyalty(offer.nftContractAddress, offer.nftId, offer.downPaymentAmount);

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        vm.startPrank(buyer1);
        maker.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature,
            buyer1,
            offer.nftId,
            address(seaportExecuter),
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedMakerLoan(offer, offer.nftId);
        assertEq(address(maker).balance, makerBalanceBefore - (offer.price - offer.downPaymentAmount + totalRoyaltiesPaid));
    }

    function test_fuzz_buyWithFinancingMaker_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWithFinancingMaker_simplest_case(fuzzed);
    }

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
        order.parameters.orderType = ISeaport.OrderType.FULL_OPEN;
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
        vm.prank(SANCTIONED_ADDRESS);
        boredApeYachtClub.transferFrom(SANCTIONED_ADDRESS, seller2, order.parameters.offer[0].identifierOrCriteria);
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
                expiration: fuzzed.expiration,
                collectionOfferLimit: 1
            });
    }
}