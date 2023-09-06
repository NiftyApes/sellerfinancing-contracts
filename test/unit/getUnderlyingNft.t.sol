// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

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
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        CollateralItem memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        CollateralItem memory underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, offer.collateralItem.token);
        assertEq(underlyingBuyer.tokenId, offer.collateralItem.tokenId);
        assertEq(underlyingSeller.token, offer.collateralItem.token);
        assertEq(underlyingSeller.tokenId, offer.collateralItem.tokenId);
    }

    function test_unit_getUnderlyingNft_returns_underylingNftDetails_whenLoanActiveWithCollectionOffer() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        uint256 tokenId = offer.collateralItem.tokenId;
        offer.isCollectionOffer = true;

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), tokenId);
        vm.stopPrank();

        bytes memory signature =  signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        uint256 loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        CollateralItem memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        CollateralItem memory underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, offer.collateralItem.token);
        assertEq(underlyingBuyer.tokenId, tokenId);
        assertEq(underlyingSeller.token, offer.collateralItem.token);
        assertEq(underlyingSeller.tokenId, tokenId);
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
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();

        CollateralItem memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        CollateralItem memory underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, offer.collateralItem.token);
        assertEq(underlyingBuyer.tokenId, offer.collateralItem.tokenId);
        assertEq(underlyingSeller.token, offer.collateralItem.token);
        assertEq(underlyingSeller.tokenId, offer.collateralItem.tokenId);

        (, uint256 periodInterest,) = sellerFinancing.calculateMinimumPayment(
            loanId
        );

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: ((offer.loanTerms.principalAmount + periodInterest))
        }(loanId, (offer.loanTerms.principalAmount + periodInterest));
        vm.stopPrank();

        underlyingBuyer = sellerFinancing.getUnderlyingNft(loanId);
        underlyingSeller = sellerFinancing.getUnderlyingNft(loanId + 1);

        assertEq(underlyingBuyer.token, address(0));
        assertEq(underlyingBuyer.tokenId, 0);
        assertEq(underlyingSeller.token, address(0));
        assertEq(underlyingSeller.tokenId, 0);
    }
}
