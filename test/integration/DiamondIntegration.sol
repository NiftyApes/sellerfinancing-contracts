// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";

import "../../src/diamond/interfaces/IDiamondCut.sol";
import "../../src/diamond/interfaces/IDiamondLoupe.sol";
import "../../src/diamond/interfaces/IERC173.sol";
import "../common/BaseTest.sol";
import "./../utils/fixtures/OffersLoansFixtures.sol";
import "../common/mock/MockFacet1.sol";

contract TestDiamondIntegration is Test, BaseTest, OffersLoansFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_facetAddresses_must_return_all_seven_facets_addresses() public {
        address[] memory allfacetAddresses = diamondLoupe.facetAddresses();
        assertEq(allfacetAddresses.length, 7);
        assertEq(allfacetAddresses[0], address(diamondCutFacet));
        assertEq(allfacetAddresses[1], address(diamondLoupeFacet));
        assertEq(allfacetAddresses[2], address(ownershipFacet));
        assertEq(allfacetAddresses[3], address(adminFacet));
        assertEq(allfacetAddresses[4], address(offerFacet));
        assertEq(allfacetAddresses[5], address(loanExecFacet));
        assertEq(allfacetAddresses[6], address(loanManagFacet));
    }

    function test_facets_must_return_all_seven_facets_addresses_with_their_functionSelectors() public {
        IDiamondLoupe.Facet[] memory allFacets = diamondLoupe.facets();
        assertEq(allFacets.length, 7);
        assertEq(allFacets[0].facetAddress, address(diamondCutFacet));
        assertEq(allFacets[1].facetAddress, address(diamondLoupeFacet));
        assertEq(allFacets[2].facetAddress, address(ownershipFacet));
        assertEq(allFacets[3].facetAddress, address(adminFacet));
        assertEq(allFacets[4].facetAddress, address(offerFacet));
        assertEq(allFacets[5].facetAddress, address(loanExecFacet));
        assertEq(allFacets[6].facetAddress, address(loanManagFacet));

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

        assertEq(allFacets[3].functionSelectors.length, 12);
        assertEq(allFacets[3].functionSelectors[0], adminFacet.updateRoyaltiesEngineContractAddress.selector);
        assertEq(allFacets[3].functionSelectors[1], adminFacet.updateDelegateRegistryContractAddress.selector);
        assertEq(allFacets[3].functionSelectors[2], adminFacet.updateSeaportContractAddress.selector);
        assertEq(allFacets[3].functionSelectors[11], adminFacet.unpauseSanctions.selector);

        assertEq(allFacets[4].functionSelectors.length, 6);
        assertEq(allFacets[4].functionSelectors[0], offerFacet.getOfferHash.selector);
        assertEq(allFacets[4].functionSelectors[1], offerFacet.getOfferSigner.selector);
        assertEq(allFacets[4].functionSelectors[5], offerFacet.withdrawAllOffers.selector);

        assertEq(allFacets[5].functionSelectors.length, 16);
        assertEq(allFacets[5].functionSelectors[0], loanExecFacet.onERC721Received.selector);
        assertEq(allFacets[5].functionSelectors[1], loanExecFacet.buyWithSellerFinancing.selector);
        assertEq(allFacets[5].functionSelectors[2], loanExecFacet.borrow.selector);
        assertEq(allFacets[5].functionSelectors[3], loanExecFacet.buyWith3rdPartyFinancing.selector);
        assertEq(allFacets[5].functionSelectors[10], loanExecFacet.name.selector);
        assertEq(allFacets[5].functionSelectors[15], loanExecFacet.isApprovedForAll.selector);

        assertEq(allFacets[6].functionSelectors.length, 7);
        assertEq(allFacets[6].functionSelectors[0], loanManagFacet.makePayment.selector);
        assertEq(allFacets[6].functionSelectors[1], loanManagFacet.seizeAsset.selector);
        assertEq(allFacets[6].functionSelectors[6], loanManagFacet.makePaymentBatch.selector);
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

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(adminFacet));
        assertEq(facetFunctionSelectors.length, 12);
        assertEq(facetFunctionSelectors[0], adminFacet.updateRoyaltiesEngineContractAddress.selector);
        assertEq(facetFunctionSelectors[1], adminFacet.updateDelegateRegistryContractAddress.selector);
        assertEq(facetFunctionSelectors[2], adminFacet.updateSeaportContractAddress.selector);
        assertEq(facetFunctionSelectors[10], adminFacet.pauseSanctions.selector);

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(offerFacet));
        assertEq(facetFunctionSelectors.length, 6);
        // assertEq(facetFunctionSelectors[0], lendingFacet.borrow.selector);
        // assertEq(facetFunctionSelectors[1], lendingFacet.buyWith3rdPartyFinancing.selector);

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(loanExecFacet));
        assertEq(facetFunctionSelectors.length, 16);
        // assertEq(facetFunctionSelectors[0], lendingFacet.borrow.selector);
        // assertEq(facetFunctionSelectors[1], lendingFacet.buyWith3rdPartyFinancing.selector);

        facetFunctionSelectors = diamondLoupe.facetFunctionSelectors(address(loanManagFacet));
        assertEq(facetFunctionSelectors.length, 7);
        // assertEq(facetFunctionSelectors[0], lendingFacet.borrow.selector);
        // assertEq(facetFunctionSelectors[1], lendingFacet.buyWith3rdPartyFinancing.selector);
    }

    function test_facetAddress_must_return_correctAddresses_for_each_selector() public {
        assertEq(diamondLoupe.facetAddress(diamondCutFacet.diamondCut.selector), address(diamondCutFacet));
        assertEq(diamondLoupe.facetAddress(diamondLoupeFacet.facets.selector), address(diamondLoupeFacet));
        assertEq(diamondLoupe.facetAddress(ownershipFacet.transferOwnership.selector), address(ownershipFacet));
        assertEq(diamondLoupe.facetAddress(adminFacet.updateDelegateRegistryContractAddress.selector), address(adminFacet));
        assertEq(diamondLoupe.facetAddress(offerFacet.getOfferHash.selector), address(offerFacet));
        assertEq(diamondLoupe.facetAddress(loanExecFacet.borrow.selector), address(loanExecFacet));
        assertEq(diamondLoupe.facetAddress(loanManagFacet.makePayment.selector), address(loanManagFacet));
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
        allFacetSelectors[0] = mockFacet.mockAddress.selector;
        allFacetSelectors[1] = mockFacet.mockValue.selector;

        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](1);
        facetCut[0] = IDiamondCut.FacetCut(address(mockFacet), IDiamondCut.FacetCutAction.Add, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        assertEq(MockFacet1(address(diamond)).mockAddress(), address(0));
        assertEq(MockFacet1(address(diamond)).mockValue(), 0);
    }

    function test_diamondCut_removes_functions_from_facets() public {
        MockFacet1 mockFacet = new MockFacet1();

        bytes4[] memory allFacetSelectors = new bytes4[](2);
        allFacetSelectors[0] = mockFacet.mockAddress.selector;
        allFacetSelectors[1] = mockFacet.mockValue.selector;

        IDiamondCut.FacetCut[] memory facetCut = new IDiamondCut.FacetCut[](1);
        facetCut[0] = IDiamondCut.FacetCut(address(mockFacet), IDiamondCut.FacetCutAction.Add, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        assertEq(MockFacet1(address(diamond)).mockAddress(), address(0));
        assertEq(MockFacet1(address(diamond)).mockValue(), 0);

        facetCut[0] = IDiamondCut.FacetCut(address(0), IDiamondCut.FacetCutAction.Remove, allFacetSelectors);

        vm.prank(owner);
        diamondCut.diamondCut(facetCut, address(0), bytes("0"));

        vm.expectRevert("Diamond: Function does not exist");
        MockFacet1(address(diamond)).mockAddress();
        vm.expectRevert("Diamond: Function does not exist");
        MockFacet1(address(diamond)).mockValue();
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
}
