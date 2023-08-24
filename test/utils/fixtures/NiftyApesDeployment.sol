// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
// import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../../../src/interfaces/niftyapes/INiftyApes.sol";
import "../../../src/facets/AdminFacet.sol";
import "../../../src/facets/OfferFacet.sol";
import "../../../src/facets/LoanExecutionFacet.sol";
import "../../../src/facets/LoanManagementFacet.sol";
import "../../../src/facets/BatchExecutionFacet.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";
import "../../../src/erc721MintFinancing/ERC721MintFinancing.sol";
import { DiamondDeployment } from "./DiamondDeployment.sol";
import "../../../src/diamond/interfaces/IDiamondCut.sol";

import "forge-std/Test.sol";

// deploy & initializes SellerFinancing contracts
contract NiftyApesDeployment is Test, DiamondDeployment {

    NiftyApesAdminFacet adminFacet;
    NiftyApesOfferFacet offerFacet;
    NiftyApesLoanExecutionFacet loanExecFacet;
    NiftyApesLoanManagementFacet loanManagFacet;
    NiftyApesBatchExecutionFacet batchFacet;
    INiftyApes sellerFinancing;

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

        adminFacet = new NiftyApesAdminFacet();

        bytes4[] memory allAdminSelectors = new bytes4[](16);
        allAdminSelectors[0] = adminFacet.updateRoyaltiesEngineContractAddress.selector;
        allAdminSelectors[1] = adminFacet.updateDelegateRegistryContractAddress.selector;
        allAdminSelectors[2] = adminFacet.updateSeaportContractAddress.selector;
        allAdminSelectors[3] = adminFacet.updateWethContractAddress.selector;
        allAdminSelectors[4] = adminFacet.royaltiesEngineContractAddress.selector;
        allAdminSelectors[5] = adminFacet.delegateRegistryContractAddress.selector;
        allAdminSelectors[6] = adminFacet.seaportContractAddress.selector;
        allAdminSelectors[7] = adminFacet.wethContractAddress.selector;
        allAdminSelectors[8] = adminFacet.pause.selector;
        allAdminSelectors[9] = adminFacet.unpause.selector;
        allAdminSelectors[10] = adminFacet.pauseSanctions.selector;
        allAdminSelectors[11] = adminFacet.unpauseSanctions.selector;
        allAdminSelectors[12] = adminFacet.updateProtocolFeeBPS.selector;
        allAdminSelectors[13] = adminFacet.protocolFeeBPS.selector;
        allAdminSelectors[14] = adminFacet.updateProtocolFeeRecipient.selector;
        allAdminSelectors[15] = adminFacet.protocolFeeRecipient.selector;

        offerFacet = new NiftyApesOfferFacet();
        bytes4[] memory allOfferSelectors = new bytes4[](6);
        // before loan is created: offer related functions
        allOfferSelectors[0] = offerFacet.getOfferHash.selector;
        allOfferSelectors[1] = offerFacet.getOfferSigner.selector;
        allOfferSelectors[2] = offerFacet.getOfferSignatureStatus.selector;
        allOfferSelectors[3] = offerFacet.getCollectionOfferCount.selector;
        allOfferSelectors[4] = offerFacet.withdrawOfferSignature.selector;
        allOfferSelectors[5] = offerFacet.withdrawAllOffers.selector;

        loanExecFacet = new NiftyApesLoanExecutionFacet();
        bytes4[] memory allLoanExecutionSelectors = new bytes4[](18);
        // while loan is created: misc
        allLoanExecutionSelectors[0] = loanExecFacet.onERC721Received.selector;
        allLoanExecutionSelectors[1] = loanExecFacet.buyWithSellerFinancing.selector;
        allLoanExecutionSelectors[2] = loanExecFacet.borrow.selector;
        allLoanExecutionSelectors[3] = loanExecFacet.buyWith3rdPartyFinancing.selector;
        // after loan is created: ticket management
        allLoanExecutionSelectors[4] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        allLoanExecutionSelectors[5] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        allLoanExecutionSelectors[6] = loanExecFacet.transferFrom.selector;
        allLoanExecutionSelectors[7] = loanExecFacet.ownerOf.selector;
        allLoanExecutionSelectors[8] = loanExecFacet.tokenURI.selector;
        allLoanExecutionSelectors[9] = loanExecFacet.balanceOf.selector;
        allLoanExecutionSelectors[10] = loanExecFacet.name.selector;
        allLoanExecutionSelectors[11] = loanExecFacet.symbol.selector;
        allLoanExecutionSelectors[12] = loanExecFacet.approve.selector;
        allLoanExecutionSelectors[13] = loanExecFacet.getApproved.selector;
        allLoanExecutionSelectors[14] = loanExecFacet.setApprovalForAll.selector;
        allLoanExecutionSelectors[15] = loanExecFacet.isApprovedForAll.selector;
        allLoanExecutionSelectors[16] = loanExecFacet.onERC1155Received.selector;
        allLoanExecutionSelectors[17] = loanExecFacet.buyNow.selector;
        
        loanManagFacet = new NiftyApesLoanManagementFacet();
        bytes4[] memory allLoanManagementSelectors = new bytes4[](7);
        // after loan is created: loan management
        allLoanManagementSelectors[0] = loanManagFacet.makePayment.selector;
        allLoanManagementSelectors[1] = loanManagFacet.seizeAsset.selector;
        allLoanManagementSelectors[2] = loanManagFacet.instantSell.selector;
        allLoanManagementSelectors[3] = loanManagFacet.calculateMinimumPayment.selector;
        allLoanManagementSelectors[4] = loanManagFacet.getLoan.selector;
        allLoanManagementSelectors[5] = loanManagFacet.getUnderlyingNft.selector;
        allLoanManagementSelectors[6] = loanManagFacet.makePaymentBatch.selector;

        batchFacet = new NiftyApesBatchExecutionFacet();
        bytes4[] memory allBatchSelectors = new bytes4[](1);
        // after loan is created: loan management
        allBatchSelectors[0] = batchFacet.buyWithSellerFinancingBatch.selector;

        IDiamondCut.FacetCut[] memory diamondCuts = new IDiamondCut.FacetCut[](5);
        diamondCuts[0] = IDiamondCut.FacetCut(address(adminFacet), IDiamondCut.FacetCutAction.Add, allAdminSelectors);
        diamondCuts[1] = IDiamondCut.FacetCut(address(offerFacet), IDiamondCut.FacetCutAction.Add, allOfferSelectors);
        diamondCuts[2] = IDiamondCut.FacetCut(address(loanExecFacet), IDiamondCut.FacetCutAction.Add, allLoanExecutionSelectors);
        diamondCuts[3] = IDiamondCut.FacetCut(address(loanManagFacet), IDiamondCut.FacetCutAction.Add, allLoanManagementSelectors);
        diamondCuts[4] = IDiamondCut.FacetCut(address(batchFacet), IDiamondCut.FacetCutAction.Add, allBatchSelectors);

        IDiamondCut(address(diamond)).diamondCut(
            diamondCuts, 
            address(adminFacet),
            abi.encodeWithSelector(
                adminFacet.initialize.selector, 
                mainnetRoyaltiesEngineAddress, 
                mainnetDelegateRegistryAddress,
                SEAPORT_ADDRESS,
                WETH_ADDRESS,
                owner
            )
        );

        // declare interfaces
        sellerFinancing = INiftyApes(address(diamond));

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
