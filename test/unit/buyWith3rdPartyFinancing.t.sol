// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingErrors.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";

contract TestBuyWith3rdPartyFinancing is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoanThrough3rdPartyLender(Offer memory offer, uint256 nftId) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(borrower1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                nftId
            ),
            true
        );
        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, nftId);
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        // borrower NFT minted to borrower1
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.borrowerNftId), borrower1);
        // lender NFT minted to lender1
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loan.lenderNftId), lender1);

        
        //buyer nftId has tokenURI same as original nft
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loan.borrowerNftId),
            IERC721MetadataUpgradeable(offer.nftContractAddress).tokenURI(nftId)
        );

        // check loan struct values
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function _test_buyWith3rdPartyFinancing_simplest_case(FuzzedOfferFields memory fuzzed) private {
        Offer memory offer = offerStructFromFieldsForLending(fuzzed, defaultFixedOfferFieldsForLending);
        // vm.assume(fuzzed.principalAmount < weth.balanceOf(lender1));
        ISeaport.Order memory order = createAndValidateSeaportListingFromSeller2(offer);

        
        
        bytes memory offerSignature = lender1CreateOffer(offer);

        mintWeth(borrower1, order.parameters.consideration[0].endAmount - offer.principalAmount);

        uint256 lender1BalanceBefore = weth.balanceOf(lender1);
        uint256 borrower1BalanceBefore = weth.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        weth.approve(address(sellerFinancing), order.parameters.consideration[0].endAmount - offer.principalAmount);
        sellerFinancing.buyWith3rdPartyFinancing(
            offer,
            offerSignature,
            borrower1,
            offer.nftId,
            abi.encode(order)
        );
        vm.stopPrank();
        assertionsForExecutedLoanThrough3rdPartyLender(offer, offer.nftId);

        uint256 lender1BalanceAfter = weth.balanceOf(lender1);
        uint256 borrower1BalanceAfter = weth.balanceOf(borrower1);

        // lender1 balance reduced by loan principal amount
        assertEq(
            lender1BalanceAfter,
            (lender1BalanceBefore - offer.principalAmount)
        );

        // borrower1 balance decreased by nft price minus offer.principalAmount
        assertEq(borrower1BalanceAfter, borrower1BalanceBefore - (order.parameters.consideration[0].endAmount - offer.principalAmount));
    }

    function test_fuzz_buyWith3rdPartyFinancing_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_buyWith3rdPartyFinancing_simplest_case(fuzzed);
    }

    function test_unit_buyWith3rdPartyFinancing_simplest_case() public {
        FuzzedOfferFields memory fixedForSpeed = defaultFixedFuzzedFieldsForLendingForFastUnitTesting;
        _test_buyWith3rdPartyFinancing_simplest_case(fixedForSpeed);
    }

    function createAndValidateSeaportListingFromSeller2(Offer memory offer) internal returns (ISeaport.Order memory) {
        ISeaport.Order memory order;
        order.parameters.offerer = seller2;
        order.parameters.zone = address(0x004C00500000aD104D7DBd00e3ae0A5C00560C00);
        order.parameters.offer = new ISeaport.OfferItem[](1);
        order.parameters.offer[0].itemType = ISeaport.ItemType.ERC721;
        order.parameters.offer[0].token = address(boredApeYachtClub);
        order.parameters.offer[0].identifierOrCriteria = 8661;
        order.parameters.offer[0].startAmount = 1;
        order.parameters.offer[0].endAmount = 1;
        order.parameters.consideration = new ISeaport.ConsiderationItem[](1);
        order.parameters.consideration[0].itemType = ISeaport.ItemType.ERC20;
        order.parameters.consideration[0].token = WETH_ADDRESS;
        order.parameters.consideration[0].identifierOrCriteria = 0;
        order.parameters.consideration[0].startAmount = offer.principalAmount * 2;
        order.parameters.consideration[0].endAmount = offer.principalAmount * 2;
        order.parameters.consideration[0].recipient = seller2;
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
        order.parameters.totalOriginalConsiderationItems = 1;
        order.signature = bytes("");

        ISeaport.Order[] memory orders = new ISeaport.Order[](1);
        orders[0] = order;
        vm.prank(seller1);
        boredApeYachtClub.transferFrom(seller1, seller2, order.parameters.offer[0].identifierOrCriteria);
        vm.startPrank(seller2);
        ISeaport(SEAPORT_ADDRESS).validate(orders);
        boredApeYachtClub.approve(SEAPORT_CONDUIT, order.parameters.offer[0].identifierOrCriteria);
        vm.stopPrank();
        return order;
    }
}