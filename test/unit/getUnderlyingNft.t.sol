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
        sellerFinancing.buyWithSellerFinancing{ value: offer.terms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            offer.item.identifier
        );
        vm.stopPrank();

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, offer.item.identifier);

        UnderlyingNft memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loan.borrowerNftId);
        UnderlyingNft memory underlyingSeller = sellerFinancing.getUnderlyingNft(loan.lenderNftId);

        assertEq(underlyingBuyer.nftContractAddress, offer.item.token);
        assertEq(underlyingBuyer.nftId, offer.item.identifier);
        assertEq(underlyingSeller.nftContractAddress, offer.item.token);
        assertEq(underlyingSeller.nftId, offer.item.identifier);
    }

    function test_unit_getUnderlyingNft_returns_underylingNftDetails_whenLoanActiveWithCollectionOffer() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );
        uint256 nftId = offer.item.identifier;
        offer.isCollectionOffer = true;

        vm.startPrank(seller1);
        boredApeYachtClub.approve(address(sellerFinancing), nftId);
        vm.stopPrank();

        bytes memory signature =  signOffer(seller1_private_key, offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.terms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            nftId
        );
        vm.stopPrank();

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, nftId);

        UnderlyingNft memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loan.borrowerNftId);
        UnderlyingNft memory underlyingSeller = sellerFinancing.getUnderlyingNft(loan.lenderNftId);

        assertEq(underlyingBuyer.nftContractAddress, offer.item.token);
        assertEq(underlyingBuyer.nftId, nftId);
        assertEq(underlyingSeller.nftContractAddress, offer.item.token);
        assertEq(underlyingSeller.nftId, nftId);
    }

    function test_unit_getUnderlyingNft_returns_Zeros_whenLoanClosed() public {
        Offer memory offer = offerStructFromFields(
            defaultFixedFuzzedFieldsForFastUnitTesting,
            defaultFixedOfferFields
        );

        bytes memory signature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        sellerFinancing.buyWithSellerFinancing{ value: offer.terms.downPaymentAmount }(
            offer,
            signature,
            buyer1,
            offer.item.identifier
        );
        vm.stopPrank();

        Loan memory loan = sellerFinancing.getLoan(offer.item.token, offer.item.identifier);

        UnderlyingNft memory underlyingBuyer = sellerFinancing.getUnderlyingNft(loan.borrowerNftId);
        UnderlyingNft memory underlyingSeller = sellerFinancing.getUnderlyingNft(loan.lenderNftId);

        assertEq(underlyingBuyer.nftContractAddress, offer.item.token);
        assertEq(underlyingBuyer.nftId, offer.item.identifier);
        assertEq(underlyingSeller.nftContractAddress, offer.item.token);
        assertEq(underlyingSeller.nftId, offer.item.identifier);

        (, uint256 periodInterest) = sellerFinancing.calculateMinimumPayment(
            loan
        );

        vm.startPrank(buyer1);
        sellerFinancing.makePayment{
            value: ((loan.remainingPrincipal + periodInterest))
        }(offer.item.token, offer.item.identifier);
        vm.stopPrank();

        underlyingBuyer = sellerFinancing.getUnderlyingNft(loan.borrowerNftId);
        underlyingSeller = sellerFinancing.getUnderlyingNft(loan.lenderNftId);

        assertEq(underlyingBuyer.nftContractAddress, address(0));
        assertEq(underlyingBuyer.nftId, 0);
        assertEq(underlyingSeller.nftContractAddress, address(0));
        assertEq(underlyingSeller.nftId, 0);
    }
}
