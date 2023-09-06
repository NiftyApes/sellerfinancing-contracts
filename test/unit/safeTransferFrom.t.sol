// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";

import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../../src/interfaces/niftyapes/INiftyApesStructs.sol";
import "../../src/interfaces/niftyapes/INiftyApesErrors.sol";
import "../../src/interfaces/niftyapes/INiftyApesEvents.sol";

import "../common/Console.sol";

contract TestSafeTransferFrom is Test, OffersLoansFixtures, INiftyApesEvents {
    function setUp() public override {
        super.setUp();
    }

    function test_unit_safeTranferFrom_updates_delagates_for_buyer_ticket() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, buyer2, loanId);

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer2),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            true
        );
    }

    function test_unit_safeTranferFromData_updates_delagates_for_buyer_ticket() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, buyer2, loanId, bytes(""));

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer2),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            true
        );
    }


    function test_unit_tranferFrom_updates_delagates_for_buyer_ticket() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).transferFrom(buyer1, buyer2, loanId);

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer2),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            true
        );
    }

    function test_unit_safeTranferFrom_reverts_if_anyTransactingPartiesAreSanctioned() public {
        Offer memory offer = offerStructFromFields(defaultFixedFuzzedFieldsForFastUnitTesting, defaultFixedOfferFields);

        uint256 loanId = createOfferAndBuyWithSellerFinancing(offer);
        assertionsForExecutedLoan(offer, offer.collateralItem.tokenId, buyer1, loanId);

        vm.prank(buyer1);
        vm.expectRevert(
            abi.encodeWithSelector(
                INiftyApesErrors.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, SANCTIONED_ADDRESS, loanId);

        vm.prank(owner);
        sellerFinancing.pauseSanctions();

        vm.prank(buyer1);
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(buyer1, SANCTIONED_ADDRESS, loanId);

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
            ),
            false
        );

        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                SANCTIONED_ADDRESS,
                address(sellerFinancing),
                address(boredApeYachtClub),
                offer.collateralItem.tokenId
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
        IERC721Upgradeable(address(sellerFinancing)).safeTransferFrom(SANCTIONED_ADDRESS, buyer1, loanId);
    }
}
