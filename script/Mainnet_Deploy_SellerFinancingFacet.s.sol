pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/diamond/facets/DiamondCutFacet.sol";
import "../src/diamond/interfaces/IDiamondCut.sol";
import "../src/diamond/facets/DiamondLoupeFacet.sol";
import "../src/diamond/facets/OwnershipFacet.sol";
import "../src/diamond/Diamond.sol";
import "../src/diamond/interfaces/IERC173.sol";
import "../src/facets/SellerFinancingFacet.sol";

contract DeploySellerFinancingFacetMainnet is Script {
    NiftyApesSellerFinancingFacet sellerFinancingFacet;
    IDiamondCut diamond;

    address constant DIAMOND_PROXY_ADDRESS = 0xa99755b549e9BfaBE0969CcA4Ea0f652272C896F;

    address constant SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant mainnetRoyaltiesEngineAddress = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;
    address constant mainnetDelegateRegistryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;

    function run() external {

        // account address of the private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        sellerFinancingFacet = new NiftyApesSellerFinancingFacet();

        diamond = IDiamondCut(DIAMOND_PROXY_ADDRESS);

        bytes4[] memory allSellerFinancingSelectors = new bytes4[](30);
        allSellerFinancingSelectors[0] = sellerFinancingFacet.updateRoyaltiesEngineContractAddress.selector;
        allSellerFinancingSelectors[1] = sellerFinancingFacet.updateDelegateRegistryContractAddress.selector;
        allSellerFinancingSelectors[2] = sellerFinancingFacet.updateSeaportContractAddress.selector;
        allSellerFinancingSelectors[3] = sellerFinancingFacet.updateWethContractAddress.selector;
        allSellerFinancingSelectors[4] = sellerFinancingFacet.royaltiesEngineContractAddress.selector;
        allSellerFinancingSelectors[5] = sellerFinancingFacet.delegateRegistryContractAddress.selector;
        allSellerFinancingSelectors[6] = sellerFinancingFacet.seaportContractAddress.selector;
        allSellerFinancingSelectors[7] = sellerFinancingFacet.wethContractAddress.selector;
        allSellerFinancingSelectors[8] = sellerFinancingFacet.pause.selector;
        allSellerFinancingSelectors[9] = sellerFinancingFacet.unpause.selector;
        allSellerFinancingSelectors[10] = sellerFinancingFacet.pauseSanctions.selector;
        allSellerFinancingSelectors[11] = sellerFinancingFacet.unpauseSanctions.selector;
        allSellerFinancingSelectors[12] = sellerFinancingFacet.getOfferHash.selector;
        allSellerFinancingSelectors[13] = sellerFinancingFacet.getOfferSigner.selector;
        allSellerFinancingSelectors[14] = sellerFinancingFacet.getOfferSignatureStatus.selector;
        allSellerFinancingSelectors[15] = sellerFinancingFacet.getCollectionOfferCount.selector;
        allSellerFinancingSelectors[16] = sellerFinancingFacet.withdrawOfferSignature.selector;
        allSellerFinancingSelectors[17] = sellerFinancingFacet.buyWithSellerFinancing.selector;
        allSellerFinancingSelectors[18] = sellerFinancingFacet.makePayment.selector;
        allSellerFinancingSelectors[19] = sellerFinancingFacet.seizeAsset.selector;
        allSellerFinancingSelectors[20] = sellerFinancingFacet.instantSell.selector;
        allSellerFinancingSelectors[21] = sellerFinancingFacet.calculateMinimumPayment.selector;
        allSellerFinancingSelectors[22] = sellerFinancingFacet.getLoan.selector;
        allSellerFinancingSelectors[23] = sellerFinancingFacet.getUnderlyingNft.selector;
        allSellerFinancingSelectors[24] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        allSellerFinancingSelectors[25] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        allSellerFinancingSelectors[26] = sellerFinancingFacet.transferFrom.selector;
        allSellerFinancingSelectors[27] = sellerFinancingFacet.ownerOf.selector;
        allSellerFinancingSelectors[28] = sellerFinancingFacet.tokenURI.selector;
        allSellerFinancingSelectors[29] = sellerFinancingFacet.onERC721Received.selector;

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        diamondCut[0] = IDiamondCut.FacetCut(address(sellerFinancingFacet), IDiamondCut.FacetCutAction.Add, allSellerFinancingSelectors);

        diamond.diamondCut(
            diamondCut, 
            address(sellerFinancingFacet),
            abi.encodeWithSelector(
                sellerFinancingFacet.initialize.selector,
                mainnetRoyaltiesEngineAddress, 
                mainnetDelegateRegistryAddress,
                SEAPORT_ADDRESS,
                WETH_ADDRESS
            )
        );
        
        vm.stopBroadcast();
    }
}
