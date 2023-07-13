// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";

contract TestGetUnderlyingNft is
    Test,
    BaseTest,
    INiftyApesStructs,
    OffersLoansFixtures
{
    uint256 immutable SIGNER_PRIVATE_KEY_1 =
        0x60b919c82f0b4791a5b7c6a7275970ace1748759ebdaa4076d7eeed9dbcff3c3;
    address immutable SIGNER_1 = 0x503408564C50b43208529faEf9bdf9794c015d52;

    function setUp() public override {
        super.setUp();
    }

    function test_unit_getUnderlyingNft_returns_underylingNftDetails_whenLoanActive() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );

        bytes memory signature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();

        CollateralItem memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        CollateralItem memory underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, offer.collateralItem.token);
        assertEq(underlyingBuyer.identifier, offer.collateralItem.identifier);
        assertEq(underlyingSeller.token, offer.collateralItem.token);
        assertEq(underlyingSeller.identifier, offer.collateralItem.identifier);
    }

    function test_unit_getUnderlyingNft_returns_underylingNftDetails_whenLoanActiveWithCollectionOffer() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        uint256 nftId = offer.collateralItem.identifier;
        offer.isCollectionOffer = true;

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId);
        vm.stopPrank();

        bytes memory signature =  signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            nftId
        );
        vm.stopPrank();

        CollateralItem memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        CollateralItem memory underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, offer.collateralItem.token);
        assertEq(underlyingBuyer.identifier, nftId);
        assertEq(underlyingSeller.token, offer.collateralItem.token);
        assertEq(underlyingSeller.identifier, nftId);
    }

    function test_unit_getUnderlyingNft_returns_Zeros_whenLoanClosed() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );

        bytes memory signature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            offer.collateralItem.identifier
        );
        vm.stopPrank();

        CollateralItem memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        CollateralItem memory underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, offer.collateralItem.token);
        assertEq(underlyingBuyer.identifier, offer.collateralItem.identifier);
        assertEq(underlyingSeller.token, offer.collateralItem.token);
        assertEq(underlyingSeller.identifier, offer.collateralItem.identifier);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: ((offer.loanTerms.principalAmount + periodInterest))
        }(loanId);
        vm.stopPrank();

        underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, address(0));
        assertEq(underlyingBuyer.identifier, 0);
        assertEq(underlyingSeller.token, address(0));
        assertEq(underlyingSeller.identifier, 0);
    }
}
