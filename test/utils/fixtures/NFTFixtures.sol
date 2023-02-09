pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/StringsUpgradeable.sol";
import "forge-std/Test.sol";

import "./UsersFixtures.sol";

import "../../mock/ERC721Mock.sol";

import "forge-std/Test.sol";

// mints NFTs to sellers
contract NFTFixtures is Test, UsersFixtures {
    ERC721Mock internal mockNft;

    bool internal integration = false;

    function setUp() public virtual override {
        super.setUp();

        mockNft = new ERC721Mock();
        mockNft.initialize("BoredApe", "BAYC");

        mockNft.safeMint(address(seller1), 1);
        mockNft.safeMint(address(seller2), 2);
        mockNft.safeMint(address(seller2), 3);
        mockNft.safeMint(SANCTIONED_ADDRESS, 4);
    }
}
