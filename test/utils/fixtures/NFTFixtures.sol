pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "forge-std/Test.sol";
import "../../common/BaseTest.sol";

import "./UsersFixtures.sol";

// mints NFTs to sellers
contract NFTFixtures is Test, BaseTest, UsersFixtures {
    address public flamingoDAO = 0xB88F61E6FbdA83fbfffAbE364112137480398018;
    IERC721Upgradeable boredApeYachtClub =
        IERC721Upgradeable(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);

    function setUp() public virtual override {
        vm.rollFork(16901983);
        super.setUp();

        vm.startPrank(flamingoDAO);

        boredApeYachtClub.transferFrom(flamingoDAO, address(seller1), 8661);
        boredApeYachtClub.transferFrom(flamingoDAO, SANCTIONED_ADDRESS , 6974);

        vm.stopPrank();
    }
}
