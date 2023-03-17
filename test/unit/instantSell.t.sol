// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";
import "../../src/interfaces/seaport/ISeaport.sol";

import "../common/Console.sol";

contract TestInstantSell is Test, OffersLoansFixtures {
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

    function assertionsForClosedLoan(
        Offer memory offer,
        address expectedNftOwner
    ) private {
        // expected address has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), expectedNftOwner);

        // loan reciept balance decrements to zero
        assertEq(
            sellerFinancing.balanceOf(buyer1, address(boredApeYachtClub)),
            0
        );

        assertEq(
            sellerFinancing.balanceOf(seller1, address(boredApeYachtClub)),
            0
        );
        // nftId does not exist at index 0
        vm.expectRevert("00069");
        assertEq(
            sellerFinancing.tokenOfOwnerByIndex(
                buyer1,
                address(boredApeYachtClub),
                0
            ),
            0
        );

        // nftId does not exist at index 0
        vm.expectRevert("00069");
        assertEq(
            sellerFinancing.tokenOfOwnerByIndex(
                buyer1,
                address(boredApeYachtClub),
                1
            ),
            0
        );
        // loan doesn't exist anymore
        assertEq(
            sellerFinancing
                .getLoan(address(boredApeYachtClub), offer.nftId)
                .periodBeginTimestamp,
            0
        );
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(0),
            address(0)
        );
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(
            IERC721Upgradeable(address(sellerFinancing)).ownerOf(1),
            address(0)
        );
    }

    function _test_instantSell_loanClosed_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) private {
        

        Offer memory offer = offerStructFromFields(
            fuzzed,
            defaultFixedOfferFields
        );

        (
            address payable[] memory recipients1,
            uint256[] memory amounts1
        ) = IRoyaltyEngineV1(0x0385603ab55642cb4Dd5De3aE9e306809991804f)
                .getRoyalty(
                    offer.nftContractAddress,
                    offer.nftId,
                    offer.downPaymentAmount
                );

        uint256 totalRoyaltiesPaid;

        // payout royalties
        for (uint256 i = 0; i < recipients1.length; i++) {
            totalRoyaltiesPaid += amounts1[i];
        }

        uint256 buyer1BalanceBefore = address(buyer1).balance;
        createOfferAndBuyWithFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(
            offer.nftContractAddress,
            offer.nftId
        );

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        (
            address payable[] memory recipients2,
            uint256[] memory amounts2
        ) = IRoyaltyEngineV1(0x0385603ab55642cb4Dd5De3aE9e306809991804f)
                .getRoyalty(
                    offer.nftContractAddress,
                    offer.nftId,
                    (loan.remainingPrincipal + periodInterest)
                );

        // payout royalties
        for (uint256 i = 0; i < recipients2.length; i++) {
            totalRoyaltiesPaid += amounts2[i];
        }

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = ((loan.remainingPrincipal + periodInterest + minProfitAmount) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0], bytes32(0))
        );
        vm.stopPrank();

        assertionsForClosedLoan(offer, buyer2);
        uint256 buyer1BalanceAfter = address(buyer1).balance;
        assertEq(
            buyer1BalanceAfter,
            (buyer1BalanceBefore - offer.downPaymentAmount + minProfitAmount)
        );
    }

    function test_fuzz_instantSell_loanClosed_simplest_case(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_loanClosed_simplest_case(fuzzed);
    }

    function test_unit_instantSell_loanClosed_simplest_case() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_loanClosed_simplest_case(fixedForSpeed);
    }

    function _test_instantSell_reverts_post_grace_period(
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

        skip(loan.periodDuration * 2);

        (, uint256 totalInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        // set any minimum profit value
        uint256 minProfitAmount = 1 ether;

        // adding 2.5% opnesea fee amount
        uint256 bidPrice = (((loan.remainingPrincipal + totalInterest) + minProfitAmount) * 40 + 38) / 39;

        ISeaport.Order[] memory order = _createOrder(
            offer.nftContractAddress,
            offer.nftId,
            bidPrice,
            buyer2
        );
        mintWeth(buyer2, bidPrice);

        vm.startPrank(buyer2);
        IERC20Upgradeable(WETH_ADDRESS).approve(SEAPORT_CONDUIT, bidPrice);
        ISeaport(SEAPORT_ADDRESS).validate(order);
        vm.stopPrank();

        vm.startPrank(buyer1);
        vm.expectRevert("cannot make payment, past soft grace period");
        sellerFinancing.instantSell(
            offer.nftContractAddress,
            offer.nftId,
            minProfitAmount,
            abi.encode(order[0], bytes32(0))
        );
        vm.stopPrank();
    }

    function test_fuzz_instantSell_reverts_post_grace_period(
        FuzzedOfferFields memory fuzzed
    ) public validateFuzzedOfferFields(fuzzed) {
        _test_instantSell_reverts_post_grace_period(fuzzed);
    }

    function test_unit_instantSell_reverts_post_grace_period() public {
        FuzzedOfferFields
            memory fixedForSpeed = defaultFixedFuzzedFieldsForFastUnitTesting;
        _test_instantSell_reverts_post_grace_period(fixedForSpeed);
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
        order[0] = ISeaport.Order(
            {
                parameters: ISeaport.OrderParameters(
                    {
                        offerer: payable(orderCreator),
                        zone: 0x004C00500000aD104D7DBd00e3ae0A5C00560C00,
                        offer: new ISeaport.OfferItem[](1),
                        consideration: new ISeaport.ConsiderationItem[](2),
                        orderType: ISeaport.OrderType.FULL_OPEN,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 24*60*60,
                        zoneHash: bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
                        salt: 1,
                        conduitKey: bytes32(0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000),
                        totalOriginalConsiderationItems: 2
                    }
                ),
                signature: bytes("")
            }
        );
        order[0].parameters.offer[0] = ISeaport.OfferItem(
            {
                itemType: offerItemType,
                token: offerToken,
                identifierOrCriteria: 0,
                startAmount: bidPrice,
                endAmount: bidPrice
            }
        );
        order[0].parameters.consideration[0] = ISeaport.ConsiderationItem(
            {
                itemType: ISeaport.ItemType.ERC721,
                token: nftContractAddress,
                identifierOrCriteria: nftId,
                startAmount: 1,
                endAmount: 1,
                recipient: payable(orderCreator)
            }
        );
        order[0].parameters.consideration[1] = ISeaport.ConsiderationItem(
            {
                itemType: offerItemType,
                token: offerToken,
                identifierOrCriteria: 0,
                startAmount: seaportFeeAmount,
                endAmount: seaportFeeAmount,
                recipient: payable(0x0000a26b00c1F0DF003000390027140000fAa719)
            }
        );
    }

}
