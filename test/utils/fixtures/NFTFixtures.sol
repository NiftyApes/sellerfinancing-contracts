pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Upgradeable.sol";
import "forge-std/Test.sol";
import "../../common/BaseTest.sol";

import "./UsersFixtures.sol";

// mints NFTs to sellers
contract NFTFixtures is Test, BaseTest, UsersFixtures {
    address public flamingoDAO = 0xB88F61E6FbdA83fbfffAbE364112137480398018;
    IERC721Upgradeable boredApeYachtClub =
        IERC721Upgradeable(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D);

    IERC1155Upgradeable public erc1155Token = IERC1155Upgradeable(0xa42Bd534270dD4C934D970429392Ce335c79220D);
    uint256 public erc1155Token27638 = 27638;

    function setUp() public virtual override {
        vm.rollFork(16901983);
        super.setUp();

        vm.startPrank(flamingoDAO);

        boredApeYachtClub.transferFrom(flamingoDAO, address(seller1), 8661);
        boredApeYachtClub.transferFrom(flamingoDAO, SANCTIONED_ADDRESS , 6974);
        vm.stopPrank();

        vm.startPrank(0x6446aD9821021Eeb9f85B8a18B0153d58166d161);
        erc1155Token.safeTransferFrom(
            0x6446aD9821021Eeb9f85B8a18B0153d58166d161,
            address(seller1),
            erc1155Token27638,
            100,
            bytes("")
        );
        erc1155Token.safeTransferFrom(
            0x6446aD9821021Eeb9f85B8a18B0153d58166d161,
            address(buyer1),
            erc1155Token27638,
            100,
            bytes("")
        );
        vm.stopPrank();
    }
}
