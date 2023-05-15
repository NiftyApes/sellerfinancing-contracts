pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import "../src/diamond/facets/DiamondCutFacet.sol";
import "../src/diamond/interfaces/IDiamondCut.sol";
import "../src/diamond/facets/DiamondLoupeFacet.sol";
import "../src/diamond/facets/OwnershipFacet.sol";
import "../src/diamond/Diamond.sol";
import "../src/diamond/upgradeInitializers/DiamondInit.sol";
import "../src/diamond/interfaces/IERC173.sol";

import "../src/SellerFinancing.sol";
import "../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "../src/interfaces/sellerFinancing/ISellerFinancingAdmin.sol";

contract DeploySellerFinancingFacet is Script {
    IDiamondCut diamond;
    DiamondInit diamondInit;

    // NiftyApesSellerFinancing sellerFinancingFacet;

    address SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() external {
        address DIAMOND_PROXY_ADDRESS = 0xa99755b549e9BfaBE0969CcA4Ea0f652272C896F;

        address goerliRoyaltiesEngineAddress = 0xe7c9Cb6D966f76f3B5142167088927Bf34966a1f;
        address goerliDelegateRegistryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;

        address sellerFinancingAddress = 0xaa07875c41EF8C8648b09B313A2194539a23829a;


        // account address of the private key
        uint256 deployerPrivateKey = vm.envUint("GOERLI_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        diamond = IDiamondCut(DIAMOND_PROXY_ADDRESS);

        bytes4[] memory allSellerFinancingSelectors = new bytes4[](10);
        allSellerFinancingSelectors[0] = ISellerFinancing.initialize.selector;
        allSellerFinancingSelectors[1] = ISellerFinancing.getOfferHash.selector;
        allSellerFinancingSelectors[2] = ISellerFinancing.buyWithFinancing.selector;
        allSellerFinancingSelectors[3] = ISellerFinancing.makePayment.selector;
        allSellerFinancingSelectors[4] = ISellerFinancing.instantSell.selector;
        allSellerFinancingSelectors[5] = ISellerFinancing.getOfferSigner.selector;
        allSellerFinancingSelectors[6] = ISellerFinancing.seizeAsset.selector;
        allSellerFinancingSelectors[7] = ISellerFinancing.seaportContractAddress.selector;
        allSellerFinancingSelectors[8] = ISellerFinancingAdmin.updateSeaportContractAddress.selector;
        allSellerFinancingSelectors[8] = ISellerFinancing.wethContractAddress.selector;

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        diamondCut[0] = IDiamondCut.FacetCut(sellerFinancingAddress, IDiamondCut.FacetCutAction.Replace, allSellerFinancingSelectors);

        diamond.diamondCut(
            diamondCut, 
            sellerFinancingAddress,
            abi.encodeWithSelector(
                ISellerFinancing.initialize.selector, 
                goerliRoyaltiesEngineAddress, 
                goerliDelegateRegistryAddress,
                SEAPORT_ADDRESS,
                WETH_ADDRESS
            )
        );
        
        vm.stopBroadcast();
    }
}
