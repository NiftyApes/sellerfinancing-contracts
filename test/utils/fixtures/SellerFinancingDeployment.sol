// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-norm/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-norm/contracts/proxy/transparent/ProxyAdmin.sol";

import "../../../src/interfaces/sellerFinancing/ISellerFinancing.sol";
import "../../../src/SellerFinancing.sol";
import "../../../src/marketplaceIntegration/MarketplaceIntegration.sol";
import "../../../src/erc721MintFinancing/ERC721MintFinancing.sol";
import "./NFTFixtures.sol";

import "forge-std/Test.sol";

// deploy & initializes SellerFinancing contracts
contract SellerFinancingDeployment is Test, NFTFixtures {
    ProxyAdmin sellerFinancingProxyAdmin;

    NiftyApesSellerFinancing sellerFinancingImplementation;
    TransparentUpgradeableProxy sellerFinancingProxy;
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

        sellerFinancingImplementation = new NiftyApesSellerFinancing();
        sellerFinancingImplementation.initialize(address(0), address(0), address(0), address(0));

        // deploy proxy admin
        sellerFinancingProxyAdmin = new ProxyAdmin();

        // deploy proxies
        sellerFinancingProxy = new TransparentUpgradeableProxy(
            address(sellerFinancingImplementation),
            address(sellerFinancingProxyAdmin),
            bytes("")
        );

        // declare interfaces
        sellerFinancing = ISellerFinancing(address(sellerFinancingProxy));

        // initialize proxies
        sellerFinancing.initialize(
            mainnetRoyaltiesEngineAddress,
            mainnetDelegateRegistryAddress,
            SEAPORT_ADDRESS,
            WETH_ADDRESS
        );

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
