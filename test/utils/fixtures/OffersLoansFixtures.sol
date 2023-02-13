// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";

import "../../utils/fixtures/SellerFinancingDeployment.sol";
import "../../../src/interfaces/sellerFinancing/ISellerFinancingStructs.sol";

import "../../common/BaseTest.sol";

uint256 constant MAX_BPS = 10_000;
uint256 constant MAX_FEE = 1_000;

// Note: need "sign" function from BaseTest for signOffer below
contract OffersLoansFixtures is
    Test,
    BaseTest,
    ISellerFinancingStructs,
    SellerFinancingDeployment
{
    struct FuzzedOfferFields {
        uint128 price;
        uint128 downPaymentAmount;
        uint128 minimumPrincipalPerPeriod;
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        uint32 expiration;
    }

    struct FixedOfferFields {
        address creator;
        uint256 nftId;
        address nftContractAddress;
    }

    FixedOfferFields internal defaultFixedOfferFields;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForFastUnitTesting;

    function setUp() public virtual override {
        super.setUp();

        // these fields are fixed, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFields = FixedOfferFields({
            creator: seller1,
            nftContractAddress: address(boredApeYachtClub),
            nftId: 8661
        });

        // in addition to fuzz tests, we have fast unit tests
        // using these default values instead of fuzzing
        defaultFixedFuzzedFieldsForFastUnitTesting = FuzzedOfferFields({
            price: 1 ether,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });
    }

    modifier validateFuzzedOfferFields(FuzzedOfferFields memory fuzzed) {
        vm.assume(fuzzed.price < ~uint96(0));
        vm.assume(fuzzed.price > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount > ~uint8(0));
        vm.assume(fuzzed.minimumPrincipalPerPeriod > ~uint8(0));
        vm.assume(fuzzed.periodInterestRateBps < 100000);

        vm.assume(fuzzed.price > fuzzed.downPaymentAmount);
        vm.assume(
            fuzzed.price - fuzzed.downPaymentAmount >
                fuzzed.minimumPrincipalPerPeriod
        );
        vm.assume(fuzzed.periodDuration > 1 days);
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
                price: fuzzed.price,
                downPaymentAmount: fuzzed.downPaymentAmount,
                minimumPrincipalPerPeriod: fuzzed.minimumPrincipalPerPeriod,
                periodInterestRateBps: fuzzed.periodInterestRateBps,
                periodDuration: fuzzed.periodDuration,
                expiration: fuzzed.expiration
            });
    }

    function signOffer(uint256 signerPrivateKey, Offer memory offer)
        public
        returns (bytes memory)
    {
        // This is the EIP712 signed hash
        bytes32 offerHash = sellerFinancing.getOfferHash(offer);

        return sign(signerPrivateKey, offerHash);
    }

    function seller1CreateOffer(Offer memory offer)
        internal
        returns (bytes memory signature)
    {
        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), offer.nftId);
        vm.stopPrank();

        return signOffer(seller1_private_key, offer);
    }

    function createOfferAndBuyWithFinancing(Offer memory offer) internal {
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithFinancing{value: offer.downPaymentAmount}(
            offer,
            offerSignature
        );
        vm.stopPrank();
    }
}
