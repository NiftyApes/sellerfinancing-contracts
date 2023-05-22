// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../src/diamond/interfaces/IDiamondCut.sol";
import "../../src/diamond/interfaces/IDiamondLoupe.sol";
import "../../src/diamond/interfaces/IERC173.sol";
import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";

contract TestDiamondIntegration is Test, BaseTest, OffersLoansFixtures {
    IDiamondCut diamondCut;
    IDiamondLoupe diamondLoupe;
    IERC173 diamondOwnership;
    function setUp() public override {
        super.setUp();
        diamondCut = IDiamondCut(address(diamond));
        diamondLoupe = IDiamondLoupe(address(diamond));
        diamondOwnership = IERC173(address(diamond));
    }

    function test_facetAddresses_must_return_all_four_facets_addresses() public {
        address[] memory allfacetAddresses = diamondLoupe.facetAddresses();
        assertEq(allfacetAddresses.length, 4);
        assertEq(allfacetAddresses[0], address(diamondCutFacet));
        assertEq(allfacetAddresses[1], address(diamondLoupeFacet));
        assertEq(allfacetAddresses[2], address(ownershipFacet));
        assertEq(allfacetAddresses[3], address(sellerFinancingFacet));
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
}
