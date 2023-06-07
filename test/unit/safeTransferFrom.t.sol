// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/sellerFinancing/ISellerFinancingEvents.sol";

import "../common/Console.sol";

contract TestSafeTransferFrom is Test, OffersLoansFixtures, ISellerFinancingEvents {
    function setUp() public override {
        super.setUp();
    }

    function assertionsForExecutedLoan(Offer memory offer) private {
        // sellerFinancing contract has NFT
        assertEq(boredApeYachtClub.ownerOf(offer.nftId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );
        // loan exists
        assertEq(
            sellerFinancing.getLoan(address(boredApeYachtClub), offer.nftId).periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(0), buyer1);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(1), seller1);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);
        assertEq(loan.borrowerNftId, 0);
        assertEq(loan.lenderNftId, 1);
        assertEq(loan.remainingPrincipal, offer.principalAmount);
        assertEq(loan.minimumPrincipalPerPeriod, offer.minimumPrincipalPerPeriod);
        assertEq(loan.periodInterestRateBps, offer.periodInterestRateBps);
        assertEq(loan.periodDuration, offer.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function test_unit_safeTranferFrom_updates_delagates_for_buyer_ticket() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, buyer2, loan.borrowerNftId);

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer2),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );
    }

    function test_unit_safeTranferFromData_updates_delagates_for_buyer_ticket() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, buyer2, loan.borrowerNftId, bytes(""));

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer2),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );
    }


    function test_unit_tranferFrom_updates_delagates_for_buyer_ticket() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).transferFrom(buyer1, buyer2, loan.borrowerNftId);

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer2),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );
    }

    function test_unit_safeTranferFrom_reverts_if_anyTransactingPartiesAreSanctioned() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer);

        Loan memory loan = sellerFinancing.getLoan(offer.nftContractAddress, offer.nftId);

        vm.prank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, SANCTIONED_ADDRESS, loan.borrowerNftId);

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, SANCTIONED_ADDRESS, loan.borrowerNftId);

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                SANCTIONED_ADDRESS,
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.nftId
            ),
            true
        );

        vm.prank(owner);
        sellerFinancing.unpauseSanctions();


        vm.prank(SANCTIONED_ADDRESS);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(SANCTIONED_ADDRESS, buyer1, loan.borrowerNftId);
    }
}
