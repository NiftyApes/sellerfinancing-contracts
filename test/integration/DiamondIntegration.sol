// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../src/diamond/interfaces/IDiamondCut.sol";
import "../../src/diamond/interfaces/IDiamondLoupe.sol";
import "../../src/diamond/interfaces/IERC173.sol";
import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../common/mock/MockFacet1.sol";
import "../common/mock/MockFacet2.sol";

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

        assertEq(allFacets[3].functionSelectors.length, 37);
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
        assertEq(facetFunctionSelectors.length, 37);
        assertEq(facetFunctionSelectors[0], sellerFinancingFacet.updateRoyaltiesEngineContractAddress.selector);
        assertEq(facetFunctionSelectors[1], sellerFinancingFacet.updateDelegateRegistryContractAddress.selector);
        assertEq(facetFunctionSelectors[2], sellerFinancingFacet.updateSeaportContractAddress.selector);
        assertEq(facetFunctionSelectors[10], sellerFinancingFacet.pauseSanctions.selector);
        assertEq(facetFunctionSelectors[20], sellerFinancingFacet.instantSell.selector);
        assertEq(facetFunctionSelectors[30], sellerFinancingFacet.balanceOf.selector);
        assertEq(facetFunctionSelectors[36], sellerFinancingFacet.isApprovedForAll.selector);
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

    function test_diamondCut_reverts_if_called_by_nonOwner() public {
        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](0);
        assertEq(diamondOwnership.owner(), owner);
        vm.prank(seller1);
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));
    }

    function test_diamondCut_adds_functions_from_facets() public {
        MockFacet1 mockFacet = new MockFacet1();

        bytes4[] memory allFacetSelectors = new bytes4[](2);
        allFacetSelectors[0] = mockFacet.getValueFacet1At.selector;
        allFacetSelectors[1] = mockFacet.setValueFacet1At.selector;

        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](1);
        facetCut[0] = IDiamondCut.FacetCut(address(mockFacet), IDiamondCut.FacetCutAction.Add, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        MockFacet1(address(diamond)).setValueFacet1At(0, 1234);
        assertEq(MockFacet1(address(diamond)).getValueFacet1At(0), 1234);
    }

    function test_diamondCut_removes_functions_from_facets() public {
        MockFacet1 mockFacet = new MockFacet1();

        bytes4[] memory allFacetSelectors = new bytes4[](2);
        allFacetSelectors[0] = mockFacet.getValueFacet1At.selector;
        allFacetSelectors[1] = mockFacet.setValueFacet1At.selector;

        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](1);
        facetCut[0] = IDiamondCut.FacetCut(address(mockFacet), IDiamondCut.FacetCutAction.Add, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        MockFacet1(address(diamond)).setValueFacet1At(0, 1234);
        assertEq(MockFacet1(address(diamond)).getValueFacet1At(0), 1234);

        facetCut[0] = IDiamondCut.FacetCut(address(0), IDiamondCut.FacetCutAction.Remove, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        vm.expectRevert("Diamond: Function does not exist");
        MockFacet1(address(diamond)).setValueFacet1At(0, 1234);
        vm.expectRevert("Diamond: Function does not exist");
        MockFacet1(address(diamond)).getValueFacet1At(0);
    }

    function test_diamondCut_calls_provided_init_function() public {
        MockFacet1 mockFacet = new MockFacet1();

        bytes4[] memory allFacetSelectors = new bytes4[](2);
        allFacetSelectors[0] = mockFacet.mockAddress.selector;
        allFacetSelectors[1] = mockFacet.mockValue.selector;

        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](1);
        facetCut[0] = IDiamondCut.FacetCut(address(mockFacet), IDiamondCut.FacetCutAction.Add, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(mockFacet), abi.encodeWithSelector(mockFacet.init.selector, address(this), 1234));

        assertEq(MockFacet1(address(diamond)).mockAddress(), address(this));
        assertEq(MockFacet1(address(diamond)).mockValue(), 1234);
    }

    function test_mockFacet2Storage_doesnt_interferes_with_mockFacet1Storage() public {
        MockFacet1 mockFacet1 = new MockFacet1();
        MockFacet2 mockFacet2 = new MockFacet2();

        bytes4[] memory allFacet1Selectors = new bytes4[](2);
        allFacet1Selectors[0] = mockFacet1.setValueFacet1At.selector;
        allFacet1Selectors[1] = mockFacet1.getValueFacet1At.selector;

        bytes4[] memory allFacet2Selectors = new bytes4[](2);
        allFacet2Selectors[0] = mockFacet2.setValueFacet2At.selector;
        allFacet2Selectors[1] = mockFacet2.getValueFacet2At.selector;

        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](2);
        facetCut[0] = IDiamondCut.FacetCut(address(mockFacet1), IDiamondCut.FacetCutAction.Add, allFacet1Selectors);
        facetCut[1] = IDiamondCut.FacetCut(address(mockFacet2), IDiamondCut.FacetCutAction.Add, allFacet2Selectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        MockFacet1(address(diamond)).setValueFacet1At(0, 100);
        MockFacet1(address(diamond)).setValueFacet1At(999, 1000);

        MockFacet2(address(diamond)).setValueFacet2At(0, 200);
        MockFacet2(address(diamond)).setValueFacet2At(999, 2000);

        assertEq(MockFacet1(address(diamond)).getValueFacet1At(0), 100);
        assertEq(MockFacet1(address(diamond)).getValueFacet1At(999), 1000);
        assertEq(MockFacet2(address(diamond)).getValueFacet2At(0), 200);
        assertEq(MockFacet2(address(diamond)).getValueFacet2At(999), 2000);
    }
}
