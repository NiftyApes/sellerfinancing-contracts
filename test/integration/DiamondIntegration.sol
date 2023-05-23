// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../src/diamond/interfaces/IDiamondCut.sol";
import "../../src/diamond/interfaces/IDiamondLoupe.sol";
import "../../src/diamond/interfaces/IERC173.sol";
import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestDiamondIntegration is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_facetAddresses_must_return_all_four_facets_addresses() public {
        address[] memory allfacetAddresses = diamondLoupe.facetAddresses();
        assertEq(allfacetAddresses.length, 4);
        assertEq(allfacetAddresses[0], address(diamondCutFacet));
        assertEq(allfacetAddresses[1], address(diamondLoupeFacet));
        assertEq(allfacetAddresses[2], address(ownershipFacet));
        assertEq(allfacetAddresses[3], address(sellerFinancingFacet));
    }

    function test_facets_must_return_all_four_facets_addresses_with_their_functionSelectors() public {
        IDiamondLoupe.Facet[] memory allFacets = diamondLoupe.facets();
        assertEq(allFacets.length, 4);
        assertEq(allFacets[0].facetAddress, address(diamondCutFacet));
        assertEq(allFacets[1].facetAddress, address(diamondLoupeFacet));
        assertEq(allFacets[2].facetAddress, address(ownershipFacet));
        assertEq(allFacets[3].facetAddress, address(sellerFinancingFacet));

        assertEq(allFacets[0].functionSelectors.length, 1);
        assertEq(allFacets[0].functionSelectors[0], diamondCutFacet.diamondCut.selector);

        assertEq(allFacets[1].functionSelectors.length, 5);
        assertEq(allFacets[1].functionSelectors[0], diamondLoupeFacet.facets.selector);
        assertEq(allFacets[1].functionSelectors[1], diamondLoupeFacet.facetFunctionSelectors.selector);
        assertEq(allFacets[1].functionSelectors[2], diamondLoupeFacet.facetAddresses.selector);
        assertEq(allFacets[1].functionSelectors[3], diamondLoupeFacet.facetAddress.selector);
        assertEq(allFacets[1].functionSelectors[4], diamondLoupeFacet.supportsInterface.selector);

        assertEq(allFacets[2].functionSelectors.length, 2);
        assertEq(allFacets[2].functionSelectors[0], ownershipFacet.transferOwnership.selector);
        assertEq(allFacets[2].functionSelectors[1], ownershipFacet.owner.selector);

        assertEq(allFacets[3].functionSelectors.length, 30);
        assertEq(allFacets[3].functionSelectors[0], sellerFinancingFacet.updateRoyaltiesEngineContractAddress.selector);
        assertEq(allFacets[3].functionSelectors[1], sellerFinancingFacet.updateDelegateRegistryContractAddress.selector);
        assertEq(allFacets[3].functionSelectors[2], sellerFinancingFacet.updateSeaportContractAddress.selector);
        assertEq(allFacets[3].functionSelectors[10], sellerFinancingFacet.pauseSanctions.selector);
        assertEq(allFacets[3].functionSelectors[20], sellerFinancingFacet.instantSell.selector);
        assertEq(allFacets[3].functionSelectors[29], sellerFinancingFacet.onERC721Received.selector);
    }

    function test_facetFunctionSelectors_must_return_all_added_selectors_for_each_facet() public {
        bytes4[] memory facetFunctionSelectors;
        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(diamondCutFacet));
        assertEq(facetFunctionSelectors.length, 1);
        assertEq(facetFunctionSelectors[0], diamondCutFacet.diamondCut.selector);

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(diamondLoupeFacet));
        assertEq(facetFunctionSelectors.length, 5);
        assertEq(facetFunctionSelectors[0], diamondLoupeFacet.facets.selector);
        assertEq(facetFunctionSelectors[1], diamondLoupeFacet.facetFunctionSelectors.selector);
        assertEq(facetFunctionSelectors[2], diamondLoupeFacet.facetAddresses.selector);
        assertEq(facetFunctionSelectors[3], diamondLoupeFacet.facetAddress.selector);
        assertEq(facetFunctionSelectors[4], diamondLoupeFacet.supportsInterface.selector);

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(ownershipFacet));
        assertEq(facetFunctionSelectors.length, 2);
        assertEq(facetFunctionSelectors[0], ownershipFacet.transferOwnership.selector);
        assertEq(facetFunctionSelectors[1], ownershipFacet.owner.selector);

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(sellerFinancingFacet));
        assertEq(facetFunctionSelectors.length, 30);
        assertEq(facetFunctionSelectors[0], sellerFinancingFacet.updateRoyaltiesEngineContractAddress.selector);
        assertEq(facetFunctionSelectors[1], sellerFinancingFacet.updateDelegateRegistryContractAddress.selector);
        assertEq(facetFunctionSelectors[2], sellerFinancingFacet.updateSeaportContractAddress.selector);
        assertEq(facetFunctionSelectors[10], sellerFinancingFacet.pauseSanctions.selector);
        assertEq(facetFunctionSelectors[20], sellerFinancingFacet.instantSell.selector);
        assertEq(facetFunctionSelectors[29], sellerFinancingFacet.onERC721Received.selector);
    }

    function test_facetAddress_must_return_correctAddresses_for_each_selector() public {
        assertEq(diamondLoupe.facetAddress(diamondCutFacet.diamondCut.selector), address(diamondCutFacet));
        assertEq(diamondLoupe.facetAddress(diamondLoupeFacet.facets.selector), address(diamondLoupeFacet));
        assertEq(diamondLoupe.facetAddress(ownershipFacet.transferOwnership.selector), address(ownershipFacet));
        assertEq(diamondLoupe.facetAddress(sellerFinancing.buyWithFinancing.selector), address(sellerFinancingFacet));
    }

    function test_supportsInterface_must_be_true_for_all_supported_intrerface() public {
        assertEq(IERC165(address(diamond)).supportsInterface(type(IERC165).interfaceId), true);
        assertEq(IERC165(address(diamond)).supportsInterface(type(IDiamondCut).interfaceId), true);
        assertEq(IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId), true);
        assertEq(IERC165(address(diamond)).supportsInterface(type(IERC173).interfaceId), true);
        assertEq(IERC165(address(diamond)).supportsInterface(type(IERC721Upgradeable).interfaceId), true);
        assertEq(IERC165(address(diamond)).supportsInterface(type(IERC721MetadataUpgradeable).interfaceId), true);
    }

    function test_owner_must_return_the_current_owner() public {
        assertEq(diamondOwnership.owner(), owner);
    }

    function test_transferOwnership_transfers_ownsership_if_called_by_owner() public {
        assertEq(diamondOwnership.owner(), owner);
        vm.prank(owner);
        diamondOwnership.transferOwnership(address(seller1));
        assertEq(diamondOwnership.owner(), seller1);
    }

    function test_transferOwnership_reverts_if_called_by_nonOwner() public {
        assertEq(diamondOwnership.owner(), owner);
        vm.prank(seller1);
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamondOwnership.transferOwnership(address(seller1));
    }
}
