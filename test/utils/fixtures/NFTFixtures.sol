pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "forge-std/Test.sol";

import "./UsersFixtures.sol";

import "forge-std/Test.sol";

// mints NFTs to sellers
contract NFTFixtures is Test, UsersFixtures {
    address public flamingoDAO = 0xB88F61E6FbdA83fbfffAbE364112137480398018;
    address public boredApeYachtClub =
        0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(flamingoDAO);

        IERC721Upgradeable(boredApeYachtClub).transferFrom(
            flamingoDAO,
            address(seller1),
            8661
        );
        IERC721Upgradeable(boredApeYachtClub).transferFrom(
            flamingoDAO,
            address(seller2),
            6974
        );

        vm.stopPrank();
    }
}
