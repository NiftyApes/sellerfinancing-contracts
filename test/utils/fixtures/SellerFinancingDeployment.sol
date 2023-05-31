// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
// import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../../../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "../../../src/facets/SellerFinancingFacet.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";
import "../../../src/erc721MintFinancing/ERC721MintFinancing.sol";
import { DiamondDeployment } from "./DiamondDeployment.sol";
import "../../../src/diamond/interfaces/IDiamondCut.sol";

import "forge-std/Test.sol";

// deploy & initializes SellerFinancing contracts
contract SellerFinancingDeployment is Test, DiamondDeployment {

    NiftyApesSellerFinancingFacet sellerFinancingFacet;
    ISellerFinancing sellerFinancing;

    MarketplaceIntegration marketplaceIntegration;
    ERC721MintFinancing erc721MintFinancing;

    address SEAPORT_ADDRESS = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address SEAPORT_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address SUPERRARE_MARKETPLACE = 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F;
    address mainnetRoyaltiesEngineAddress = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;
    address mainnetDelegateRegistryAddress = 0x00000000000076A84feF008CDAbe6409d2FE638B;

    uint256 SUPERRARE_MARKET_FEE_BPS = 300;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        sellerFinancingFacet = new NiftyApesSellerFinancingFacet();

        bytes4[] memory allSellerFinancingSelectors = new bytes4[](37);
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
        allSellerFinancingSelectors[17] = sellerFinancingFacet.buyWithFinancing.selector;
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
        allSellerFinancingSelectors[30] = sellerFinancingFacet.balanceOf.selector;
        allSellerFinancingSelectors[31] = sellerFinancingFacet.name.selector;
        allSellerFinancingSelectors[32] = sellerFinancingFacet.symbol.selector;
        allSellerFinancingSelectors[33] = sellerFinancingFacet.approve.selector;
        allSellerFinancingSelectors[34] = sellerFinancingFacet.getApproved.selector;
        allSellerFinancingSelectors[35] = sellerFinancingFacet.setApprovalForAll.selector;
        allSellerFinancingSelectors[36] = sellerFinancingFacet.isApprovedForAll.selector;

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](1);
        diamondCut[0] = IDiamondCut.FacetCut(address(sellerFinancingFacet), IDiamondCut.FacetCutAction.Add, allSellerFinancingSelectors);

        IDiamondCut(address(diamond)).diamondCut(
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

        // declare interfaces
        sellerFinancing = ISellerFinancing(address(diamond));

        // deploy marketplace integration
        marketplaceIntegration = new MarketplaceIntegration(
            address(sellerFinancing),
            SUPERRARE_MARKETPLACE,
            SUPERRARE_MARKET_FEE_BPS
        );

        vm.stopPrank();
        vm.startPrank(seller1);

        // deploy mint financing contracts
        erc721MintFinancing = new ERC721MintFinancing(
            "Minty mints",
            "MINT",
            address(sellerFinancing)
        );

        vm.stopPrank();

        vm.label(address(0), "NULL !!!!! ");
    }
}
