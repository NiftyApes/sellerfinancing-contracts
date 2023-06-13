// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";

import "../../utils/fixtures/NiftyApesDeployment.sol";
import "../../../src/interfaces/niftyapes/INiftyApesStructs.sol";

import "../../common/BaseTest.sol";

uint256 constant BASE_BPS = 10_000;
uint256 constant MAX_FEE = 1_000;

// Note: need "sign" function from BaseTest for signOffer below
contract OffersLoansFixtures is Test, BaseTest, INiftyApesStructs, NiftyApesDeployment {
    struct FuzzedOfferFields {
        uint128 principalAmount;
        uint128 downPaymentAmount;
        uint128 minimumPrincipalPerPeriod;
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        uint32 expiration;
    }

    struct FixedOfferFields {
        INiftyApesStructs.OfferType offerType;
        address creator;
        uint256 nftId;
        address nftContractAddress;
        bool isCollectionOffer;
        uint64 collectionOfferLimit;
        uint32 creatorOfferNonce;
    }

    FixedOfferFields internal defaultFixedOfferFields;

    FixedOfferFields internal defaultFixedOfferFieldsForLending;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForFastUnitTesting;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForLendingForFastUnitTesting;

    function setUp() public virtual override {
        super.setUp();

        // these fields are fixed, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFields = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
            creator: seller1,
            nftContractAddress: address(boredApeYachtClub),
            nftId: 8661,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0
        });

        // these fields are fixed for Lending offer, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFieldsForLending = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.LENDING,
            creator: seller1,
            nftContractAddress: address(boredApeYachtClub),
            nftId: 8661,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0
        });

        // in addition to fuzz tests, we have fast unit tests
        // using these default values instead of fuzzing
        defaultFixedFuzzedFieldsForFastUnitTesting = FuzzedOfferFields({
            principalAmount: 0.7 ether,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });

        // in addition to fuzz tests, we have fast unit tests
        // using these default values instead of fuzzing
        defaultFixedFuzzedFieldsForLendingForFastUnitTesting = FuzzedOfferFields({
            principalAmount: 1 ether,
            downPaymentAmount: 0 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });
    }

    modifier validateFuzzedOfferFields(FuzzedOfferFields memory fuzzed) {
        vm.assume(fuzzed.principalAmount < ~uint64(0));
        vm.assume(fuzzed.principalAmount > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount < ~uint64(0));
        vm.assume(fuzzed.minimumPrincipalPerPeriod > ~uint8(0));
        vm.assume(fuzzed.periodInterestRateBps < 100000);

        vm.assume(fuzzed.principalAmount > 0);
        vm.assume(fuzzed.principalAmount > fuzzed.minimumPrincipalPerPeriod);
        vm.assume(fuzzed.periodDuration > 1 minutes);
        vm.assume(fuzzed.periodDuration <= 180 days);
        vm.assume(fuzzed.expiration > block.timestamp);
        _;
    }

    function offerStructFromFields(
        FuzzedOfferFields memory fuzzed,
        FixedOfferFields memory fixedFields
    ) internal pure returns (Offer memory) {
        return
            Offer({
                creator: fixedFields.creator,
                nftId: fixedFields.nftId,
                nftContractAddress: fixedFields.nftContractAddress,
                offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
                principalAmount: fuzzed.principalAmount,
                isCollectionOffer: fixedFields.isCollectionOffer,
                downPaymentAmount: fuzzed.downPaymentAmount,
                minimumPrincipalPerPeriod: fuzzed.minimumPrincipalPerPeriod,
                periodInterestRateBps: fuzzed.periodInterestRateBps,
                periodDuration: fuzzed.periodDuration,
                expiration: fuzzed.expiration,
                collectionOfferLimit: fixedFields.collectionOfferLimit,
                creatorOfferNonce: fixedFields.creatorOfferNonce
            });
    }

    function offerStructFromFieldsForLending(
        FuzzedOfferFields memory fuzzed,
        FixedOfferFields memory fixedFields
    ) internal pure returns (Offer memory) {
        return
            Offer({
                creator: fixedFields.creator,
                nftId: fixedFields.nftId,
                nftContractAddress: fixedFields.nftContractAddress,
                offerType: INiftyApesStructs.OfferType.LENDING,
                principalAmount: fuzzed.principalAmount,
                isCollectionOffer: fixedFields.isCollectionOffer,
                downPaymentAmount: 0,
                minimumPrincipalPerPeriod: fuzzed.minimumPrincipalPerPeriod,
                periodInterestRateBps: fuzzed.periodInterestRateBps,
                periodDuration: fuzzed.periodDuration,
                expiration: fuzzed.expiration,
                collectionOfferLimit: fixedFields.collectionOfferLimit,
                creatorOfferNonce: fixedFields.creatorOfferNonce
            });
    }

    function signOffer(uint256 signerPrivateKey, Offer memory offer) public returns (bytes memory) {
        // This is the EIP712 signed hash
        bytes32 offerHash = sellerFinancing.getOfferHash(offer);

        return sign(signerPrivateKey, offerHash);
    }

    function seller1CreateOffer(Offer memory offer) internal returns (bytes memory signature) {
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.nftId);
        vm.stopPrank();

        return signOffer(seller1_private_key, offer);
    }

    function lender1CreateOffer(Offer memory offer) internal returns (bytes memory signature) {
        vm.startPrank(lender1);
        weth.approve(address(sellerFinancing), offer.principalAmount);
        vm.stopPrank();

        return signOffer(lender1_private_key, offer);
    }

    function createOfferAndBuyWithSellerFinancing(Offer memory offer) internal {
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.nftId
        );
        vm.stopPrank();
    }

    function mintWeth(address user, uint256 amount) internal {
        IERC20Upgradeable wethToken = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address wethWhale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
        vm.startPrank(wethWhale);
        wethToken.transfer(user, amount);
        vm.stopPrank();
    }
}
