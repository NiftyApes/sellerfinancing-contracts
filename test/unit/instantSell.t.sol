// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/AddressUpgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

contract TestInstantSell is Test, ISellerFinancingStructs, OffersLoansFixtures {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address payable;

    function setUp() public override {
        // pin block to time of writing test to reflect consistent state
        vm.rollFork(15510097);
        vm.warp(1662833943);
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
        // loan exists
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

    function _test_unit_SeaportFlashSellIntegration_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );

        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        uint256 profitForTheBorrower = 1 ether; // assume any profit the borrower wants
        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + periodInterest) +
            profitForTheBorrower) *
            40 +
            38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            users[0]
        );

        // transfer weth from a weth whale
        vm.startPrank(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
        IERC20Upgradeable(WETH_ADDRESS).transfer(users[0], bidPrice * 2);
        vm.stopPrank();
        vm.startPrank(users[0]);

        IERC20Upgradeable(order[0].parameters.offer[0].token).approve(
            0x1E0049783F008A0085193E00003D00cd54003c71,
            bidPrice
        );
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        (bool valid, , , ) = ISeaport(SEAPORT_ADDRESS).getOrderStatus(
            _getOrderHash(order[0])
        );
        assertEq(valid, true);

        address nftOwnerBefore = IERC721Upgradeable(offer.nftContractAddress)
            .ownerOf(offer.nftId);
        uint256 buyer1BalanceBefore = address(buyer1).balance;

        vm.startPrank(buyer1);
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            abi.encode(order[0], bytes32(0))
        );
        vm.stopPrank();

        // Loan memory loanAfter = sellerFinancing.getLoan(
        //     offer.nftContractAddress,
        //     offer.nftId
        // );
        // address nftOwnerAfter = IERC721Upgradeable(offer.nftContractAddress)
        //     .ownerOf(offer.nftId);
        // uint256 buyer1AssetBalanceAfter = address(buyer1).balance;
        // assertEq(address(sellerFinancing), nftOwnerBefore);
        // assertEq(address(users[0]), nftOwnerAfter);
        // // assertEq(
        // //     buyer1AssetBalanceAfter - buyer1BalanceBefore,
        // //     profitForTheBorrower
        // // );
        // assertEq(loanAfter.periodBeginTimestamp, 0);
    }

    function test_unit_SeaportFlashSellIntegration_simplest_case_ETH() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_unit_SeaportFlashSellIntegration_simplest_case(fixedForSpeed);
    }

    function test_fuzz_SeaportFlashSellIntegration_simplest_case_ETH(
        FuzzedOfferFields memory fuzzedOfferData
    ) public validateFuzzedOfferFields(fuzzedOfferData) {
        _test_unit_SeaportFlashSellIntegration_simplest_case(fuzzedOfferData);
    }

    function _createOrder(
        address nftContractAddress,
        uint256 nftId,
        uint256 bidPrice,
        address orderCreator
    ) internal view returns (ISeaport.Order[] memory order) {
        uint256 seaportFeeAmount = bidPrice - (bidPrice * 39) / 40;
        ISeaport.ItemType offerItemType = ISeaport.ItemType.ERC20;
        address offerToken = WETH_ADDRESS;

        order = new ISeaport.Order[](1);
        order[0] = ISeaport.Order({
            parameters: ISeaport.OrderParameters({
                offerer: payable(orderCreator),
                zone: 0x004C00500000aD104D7DBd00e3ae0A5C00560C00,
                offer: new ISeaport.OfferItem[](1),
                consideration: new ISeaport.ConsiderationItem[](2),
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
                totalOriginalConsiderationItems: 2
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
            token: nftContractAddress,
            identifierOrCriteria: nftId,
            startAmount: 1,
            endAmount: 1,
            recipient: payable(orderCreator)
        });
        order[0].parameters.consideration[1] = ISeaport.ConsiderationItem({
            itemType: offerItemType,
            token: offerToken,
            identifierOrCriteria: 0,
            startAmount: seaportFeeAmount,
            endAmount: seaportFeeAmount,
            recipient: payable(0x0000a26b00c1F0DF003000390027140000fAa719)
        });
    }

    function _getOrderHash(ISeaport.Order memory order)
        internal
        view
        returns (bytes32 orderHash)
    {
        // Derive order hash by supplying order parameters along with counter.
        orderHash = ISeaport(SEAPORT_ADDRESS).getOrderHash(
            ISeaport.OrderComponents(
                order.parameters.offerer,
                order.parameters.zone,
                order.parameters.offer,
                order.parameters.consideration,
                order.parameters.orderType,
                order.parameters.startTime,
                order.parameters.endTime,
                order.parameters.zoneHash,
                order.parameters.salt,
                order.parameters.conduitKey,
                ISeaport(SEAPORT_ADDRESS).getCounter(order.parameters.offerer)
            )
        );
    }

    // function _test_unit_cannot_SeaportFlashSellIntegration_invalidOrderToken(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );
    //     createOfferAndTryToExecuteLoanByBorrower(offer, "should work");

    //     Loan memory loan = sellerFinancing.getloan(
    //         offer.nftContractAddress,
    //         offer.nftId
    //     );
    //     // skip time to accrue interest
    //     skip(uint256(loan.loanEndTimestamp - loan.loanBeginTimestamp) / 10);

    //     uint256 minValueRequiredToCloseTheLoan = _calculateTotalLoanPaymentAmount(
    //             loan,
    //             block.timestamp
    //         );
    //     // adding 2.5% opnesea fee amount
    //     uint256 bidPrice = ((minValueRequiredToCloseTheLoan) * 40 + 38) / 39;

    //     ISeaport.Order[] memory order = _createOrder(
    //         offer.nftContractAddress,
    //         offer.nftId,
    //         bidPrice,
    //         loan.asset,
    //         users[0]
    //     );

    //     if (loan.asset == ETH_ADDRESS) {
    //         mintWeth(users[0], bidPrice);
    //     } else {
    //         mintDai(users[0], bidPrice);
    //     }

    //     vm.startPrank(users[0]);
    //     order[0].parameters.offer[0].token = address(0xabcd);
    //     ISeaport(SEAPORT_ADDRESS).validate(order);
    //     vm.stopPrank();

    //     (bool valid, , , ) = ISeaport(SEAPORT_ADDRESS).getOrderStatus(
    //         _getOrderHash(order[0])
    //     );
    //     assertEq(valid, true);

    //     vm.startPrank(buyer1);
    //     vm.expectRevert("00067");
    //     flashSell.borrowNFTForSale(
    //         offer.nftContractAddress,
    //         offer.nftId,
    //         address(seaportFlashSell),
    //         abi.encode(order[0], bytes32(0))
    //     );
    //     vm.stopPrank();
    // }

    // function _test_unit_cannot_SeaportFlashSellIntegration_invalidOrderAmount(
    //     FuzzedOfferFields memory fuzzed
    // ) private {
    //     Offer memory offer = offerStructFromFields(
    //         fuzzed,
    //         defaultFixedOfferFields
    //     );
    //     createOfferAndTryToExecuteLoanByBorrower(offer, "should work");

    //     Loan memory loan = sellerFinancing.getloan(
    //         offer.nftContractAddress,
    //         offer.nftId
    //     );
    //     // skip time to accrue interest
    //     skip(uint256(loan.loanEndTimestamp - loan.loanBeginTimestamp) / 10);

    //     uint256 minValueRequiredToCloseTheLoan = _calculateTotalLoanPaymentAmount(
    //             loan,
    //             block.timestamp
    //         );
    //     // adding 2.5% opnesea fee amount
    //     uint256 bidPrice = ((minValueRequiredToCloseTheLoan) * 40 + 38) / 39;

    //     ISeaport.Order[] memory order = _createOrder(
    //         offer.nftContractAddress,
    //         offer.nftId,
    //         bidPrice - 1,
    //         loan.asset,
    //         users[0]
    //     );

    //     if (loan.asset == ETH_ADDRESS) {
    //         mintWeth(users[0], bidPrice);
    //     } else {
    //         mintDai(users[0], bidPrice);
    //     }

    //     vm.startPrank(users[0]);
    //     IERC20Upgradeable(order[0].parameters.offer[0].token).approve(
    //         0x1E0049783F008A0085193E00003D00cd54003c71,
    //         bidPrice
    //     );
    //     ISeaport(SEAPORT_ADDRESS).validate(order);
    //     vm.stopPrank();

    //     (bool valid, , , ) = ISeaport(SEAPORT_ADDRESS).getOrderStatus(
    //         _getOrderHash(order[0])
    //     );
    //     assertEq(valid, true);

    //     vm.startPrank(buyer1);
    //     vm.expectRevert("00066");
    //     flashSell.borrowNFTForSale(
    //         offer.nftContractAddress,
    //         offer.nftId,
    //         address(seaportFlashSell),
    //         abi.encode(order[0], bytes32(0))
    //     );
    //     vm.stopPrank();
    // }

    // function test_unit_cannot_SeaportFlashSellIntegration_invalidOrderToken()
    //     public
    // {
    //     FuzzedOfferFields
    //         memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
    //     fixedForSpeed.randomAsset = 1;
    //     _test_unit_cannot_SeaportFlashSellIntegration_invalidOrderToken(
    //         fixedForSpeed
    //     );
    // }

    // function test_unit_cannot_SeaportFlashSellIntegration_invalidOrderAmount()
    //     public
    // {
    //     FuzzedOfferFields
    //         memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
    //     fixedForSpeed.randomAsset = 1;
    //     _test_unit_cannot_SeaportFlashSellIntegration_invalidOrderAmount(
    //         fixedForSpeed
    //     );
    // }

    // function _test_cannot_SeaportFlashSellIntegration_callerNotFlashSell(
    //     Offer memory offer
    // ) private {
    //     vm.prank(buyer1);
    //     vm.expectRevert("00031");
    //     seaportFlashSell.executeOperation(
    //         offer.nftContractAddress,
    //         offer.nftId,
    //         offer.asset,
    //         offer.amount,
    //         address(seaportFlashSell),
    //         bytes("")
    //     );
    // }

    // function test_fuzz_cannot_SeaportFlashSellIntegration_callerNotFlashSell(
    //     FuzzedOfferFields memory fuzzedOfferData
    // ) public validateFuzzedOfferFields(fuzzedOfferData) {
    //     Offer memory offer = offerStructFromFields(
    //         fuzzedOfferData,
    //         defaultFixedOfferFields
    //     );
    //     _test_cannot_SeaportFlashSellIntegration_callerNotFlashSell(offer);
    // }

    // function test_unit_cannot_SeaportFlashSellIntegration_callerNotFlashSell()
    //     public
    // {
    //     Offer memory offer = offerStructFromFields(
    //         defaultFixedFuzzedFieldsForFastUnitTesting,
    //         defaultFixedOfferFields
    //     );
    //     _test_cannot_SeaportFlashSellIntegration_callerNotFlashSell(offer);
    // }

    // function _calculateTotalLoanPaymentAmount(
    //     address nftContractAddress,
    //     uint256 nftId,
    //     Loan memory loan
    // ) private view returns (uint256) {
    //     uint256 interestThresholdDelta = sellerFinancing
    //         .checkSufficientInterestAccumulated(nftContractAddress, nftId);

    //     (uint256 lenderInterest, uint256 protocolInterest) = sellerFinancing
    //         .calculateInterestAccrued(nftContractAddress, nftId);

    //     return
    //         uint256(loan.accumulatedLenderInterest) +
    //         loan.accumulatedPaidProtocolInterest +
    //         loan.unpaidProtocolInterest +
    //         loan.slashableLenderInterest +
    //         loan.amountDrawn +
    //         interestThresholdDelta +
    //         lenderInterest +
    //         protocolInterest;
    // }

    // function _getOrderHash(ISeaport.Order memory order)
    //     internal
    //     view
    //     returns (bytes32 orderHash)
    // {
    //     // Derive order hash by supplying order parameters along with counter.
    //     orderHash = ISeaport(SEAPORT_ADDRESS).getOrderHash(
    //         ISeaport.OrderComponents(
    //             order.parameters.offerer,
    //             order.parameters.zone,
    //             order.parameters.offer,
    //             order.parameters.consideration,
    //             order.parameters.orderType,
    //             order.parameters.startTime,
    //             order.parameters.endTime,
    //             order.parameters.zoneHash,
    //             order.parameters.salt,
    //             order.parameters.conduitKey,
    //             ISeaport(SEAPORT_ADDRESS).getCounter(order.parameters.offerer)
    //         )
    //     );
    // }

    // function _calculateTotalLoanPaymentAmount(Loan memory loan)
    //     internal
    //     view
    //     returns (uint256)
    // {
    //     uint256 timePassed = timestamp - loan.lastUpdatedTimestamp;

    //     uint256 lenderInterest = (timePassed * loan.interestRatePerSecond);
    //     uint256 protocolInterest = (timePassed *
    //         loan.protocolInterestRatePerSecond);

    //     uint256 interestThreshold;
    //     if (loan.loanEndTimestamp - 1 days > uint32(timestamp)) {
    //         interestThreshold =
    //             (uint256(loan.amountDrawn) * sellerFinancing.gasGriefingPremiumBps()) /
    //             10_000;
    //     }

    //     lenderInterest = lenderInterest > interestThreshold
    //         ? lenderInterest
    //         : interestThreshold;

    //     return
    //         loan.accumulatedLenderInterest +
    //         loan.accumulatedPaidProtocolInterest +
    //         loan.unpaidProtocolInterest +
    //         loan.slashableLenderInterest +
    //         loan.amountDrawn +
    //         lenderInterest +
    //         protocolInterest;
    // }
}
