pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import "../../../src/diamond/facets/DiamondCutFacet.sol";
import "../../../src/diamond/interfaces/IDiamondCut.sol";
import "../../../src/diamond/facets/DiamondLoupeFacet.sol";
import "../../../src/diamond/facets/OwnershipFacet.sol";
import "../../../src/diamond/Diamond.sol";
import "../../../src/diamond/upgradeInitializers/DiamondInit.sol";
import "../../../src/diamond/interfaces/IERC173.sol";
import "./NFTFixtures.sol";

contract DiamondDeployment is Test, NFTFixtures {
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    Diamond diamond;
    DiamondInit diamondInit;

    function setUp() public virtual override {
        super.setUp();
        
        
        vm.startPrank(owner);
        // deploy DiamondCutFacet
        diamondCutFacet = new DiamondCutFacet();

        // deploy Diamond
        diamond = new Diamond(owner, address(diamondCutFacet));

        diamondInit = new DiamondInit();

        diamondLoupeFacet  = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();

        bytes4[] memory allLoupeSelectors = new bytes4[](5);
        allLoupeSelectors[0] = diamondLoupeFacet.facets.selector;
        allLoupeSelectors[1] = diamondLoupeFacet.facetFunctionSelectors.selector;
        allLoupeSelectors[2] = diamondLoupeFacet.facetAddresses.selector;
        allLoupeSelectors[3] = diamondLoupeFacet.facetAddress.selector;
        allLoupeSelectors[4] = diamondLoupeFacet.supportsInterface.selector;

        bytes4[] memory allOwnershipSelectors = new bytes4[](2);
        allOwnershipSelectors[0] = ownershipFacet.transferOwnership.selector;
        allOwnershipSelectors[1] = ownershipFacet.owner.selector;

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](2);
        diamondCut[0] = IDiamondCut.FacetCut(address(diamondLoupeFacet), IDiamondCut.FacetCutAction.Add, allLoupeSelectors);
        diamondCut[1] = IDiamondCut.FacetCut(address(ownershipFacet), IDiamondCut.FacetCutAction.Add, allOwnershipSelectors);

        IDiamondCut(address(diamond)).diamondCut(diamondCut, address(diamondInit), abi.encode(diamondInit.init.selector));
        IERC173(address(diamond)).transferOwnership(owner);
        vm.stopPrank();
    }
}
