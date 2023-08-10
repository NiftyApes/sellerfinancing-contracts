// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import "../../utils/fixtures/NiftyApesDeployment.sol";
import "../../../src/interfaces/niftyapes/INiftyApesStructs.sol";

import "../../common/BaseTest.sol";

uint256 constant BASE_BPS = 10_000;
uint256 constant MAX_FEE = 1_000;

// Note: need "sign" function from BaseTest for signOffer below
contract OffersLoansFixtures is Test, BaseTest, INiftyApesStructs, NiftyApesDeployment {
    struct FuzzedOfferFields {
        uint128 principalAmount;
        uint128 downPaymentAmount;
        uint128 minimumPrincipalPerPeriod;
        uint32 periodInterestRateBps;
        uint32 periodDuration;
        uint32 expiration;
    }

    struct FixedOfferFields {
        INiftyApesStructs.OfferType offerType;
        address creator;
        ItemType collateralItemType;
        uint256 tokenId;
        address tokenContractAddress;
        uint256 tokenAmount;
        bool isCollectionOffer;
        uint64 collectionOfferLimit;
        uint32 creatorOfferNonce;
        ItemType loanItemType;
        address loanTokenAddress;
    }

    FixedOfferFields internal defaultFixedOfferFields;

    FixedOfferFields internal defaultFixedOfferFieldsForLending;

    FixedOfferFields internal defaultFixedOfferFieldsForLendingUSDC;

    FixedOfferFields internal defaultFixedOfferFieldsERC1155;

    FixedOfferFields internal defaultFixedOfferFieldsForLendingERC1155;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForFastUnitTesting;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForLendingForFastUnitTesting;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForFastUnitTestingUSDC;

    FuzzedOfferFields internal defaultFixedFuzzedFieldsForLendingForFastUnitTestingUSDC;

    function setUp() public virtual override {
        super.setUp();

        // these fields are fixed, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFields = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
            creator: seller1,
            collateralItemType: ItemType.ERC721,
            tokenContractAddress: address(boredApeYachtClub),
            tokenId: 8661,
            tokenAmount: 0,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0,
            loanItemType: ItemType.NATIVE,
            loanTokenAddress: address(0)
        });

        // these fields are fixed for Lending offer, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFieldsForLending = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.LENDING,
            creator: seller1,
            collateralItemType: ItemType.ERC721,
            tokenContractAddress: address(boredApeYachtClub),
            tokenId: 8661,
            tokenAmount: 0,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0,
            loanItemType: ItemType.ERC20,
            loanTokenAddress: address(WETH_ADDRESS)
        });

        defaultFixedOfferFieldsForLendingUSDC = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.LENDING,
            creator: seller1,
            collateralItemType: ItemType.ERC721,
            tokenContractAddress: address(boredApeYachtClub),
            tokenId: 8661,
            tokenAmount: 0,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0,
            loanItemType: ItemType.ERC20,
            loanTokenAddress: address(USDC_ADDRESS)
        });

        // these fields are fixed, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFieldsERC1155 = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
            creator: seller1,
            collateralItemType: ItemType.ERC1155,
            tokenContractAddress: address(erc1155Token),
            tokenId: erc1155Token27638,
            tokenAmount: 10,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0,
            loanItemType: ItemType.NATIVE,
            loanTokenAddress: address(0)
        });

        // these fields are fixed for Lending offer, not fuzzed
        // but specific fields can be overridden in tests
        defaultFixedOfferFieldsForLendingERC1155 = FixedOfferFields({
            offerType: INiftyApesStructs.OfferType.LENDING,
            creator: seller1,
            collateralItemType: ItemType.ERC1155,
            tokenContractAddress: address(erc1155Token),
            tokenId: erc1155Token27638,
            tokenAmount: 10,
            isCollectionOffer: false,
            collectionOfferLimit: 1,
            creatorOfferNonce: 0,
            loanItemType: ItemType.ERC20,
            loanTokenAddress: address(WETH_ADDRESS)
        });

        // in addition to fuzz tests, we have fast unit tests
        // using these default values instead of fuzzing
        defaultFixedFuzzedFieldsForFastUnitTesting = FuzzedOfferFields({
            principalAmount: 0.7 ether,
            downPaymentAmount: 0.3 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });

        defaultFixedFuzzedFieldsForFastUnitTestingUSDC = FuzzedOfferFields({
            principalAmount: 7e10,
            downPaymentAmount: 3e10,
            minimumPrincipalPerPeriod: 7e9,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });

        // in addition to fuzz tests, we have fast unit tests
        // using these default values instead of fuzzing
        defaultFixedFuzzedFieldsForLendingForFastUnitTesting = FuzzedOfferFields({
            principalAmount: 1 ether,
            downPaymentAmount: 0 ether,
            minimumPrincipalPerPeriod: 0.07 ether,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });

        defaultFixedFuzzedFieldsForLendingForFastUnitTestingUSDC = FuzzedOfferFields({
            principalAmount: 1e10,
            downPaymentAmount: 0,
            minimumPrincipalPerPeriod: 1e9,
            periodInterestRateBps: 25,
            periodDuration: 30 days,
            expiration: uint32(block.timestamp) + 1 days
        });
    }

    modifier validateFuzzedOfferFields(FuzzedOfferFields memory fuzzed) {
        vm.assume(fuzzed.principalAmount < ~uint64(0));
        vm.assume(fuzzed.principalAmount > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount < ~uint64(0));
        vm.assume(fuzzed.minimumPrincipalPerPeriod > ~uint8(0));
        vm.assume(fuzzed.periodInterestRateBps < 100000);

        vm.assume(fuzzed.principalAmount > 0);
        vm.assume(fuzzed.principalAmount > fuzzed.minimumPrincipalPerPeriod);
        vm.assume(fuzzed.periodDuration > 1 minutes);
        vm.assume(fuzzed.periodDuration <= 180 days);
        vm.assume(fuzzed.expiration > block.timestamp);
        _;
    }

    modifier validateFuzzedOfferFieldsForUSDC(FuzzedOfferFields memory fuzzed) {
        vm.assume(fuzzed.principalAmount < 1e12);
        vm.assume(fuzzed.principalAmount > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount > ~uint8(0));
        vm.assume(fuzzed.downPaymentAmount < 1e12);
        vm.assume(fuzzed.minimumPrincipalPerPeriod > ~uint8(0));
        vm.assume(fuzzed.periodInterestRateBps < 100000);

        vm.assume(fuzzed.principalAmount > 0);
        vm.assume(fuzzed.principalAmount > fuzzed.minimumPrincipalPerPeriod);
        vm.assume(fuzzed.periodDuration > 1 minutes);
        vm.assume(fuzzed.periodDuration <= 180 days);
        vm.assume(fuzzed.expiration > block.timestamp);
        _;
    }

    function offerStructFromFields(
        FuzzedOfferFields memory fuzzed,
        FixedOfferFields memory fixedFields
    ) internal pure returns (Offer memory) {
        return
            Offer({
                offerType: INiftyApesStructs.OfferType.SELLER_FINANCING,
                collateralItem: CollateralItem({
                    itemType: fixedFields.collateralItemType,
                    token: fixedFields.tokenContractAddress,
                    tokenId: fixedFields.tokenId,
                    amount: fixedFields.tokenAmount
                }),
                loanTerms: LoanTerms({
                    itemType: fixedFields.loanItemType,
                    token: fixedFields.loanTokenAddress,
                    tokenId: 0,
                    principalAmount: fuzzed.principalAmount,
                    minimumPrincipalPerPeriod: fuzzed.minimumPrincipalPerPeriod,
                    downPaymentAmount: fuzzed.downPaymentAmount,
                    periodInterestRateBps: fuzzed.periodInterestRateBps,
                    periodDuration: fuzzed.periodDuration
                }),
                creator: fixedFields.creator,
                expiration: fuzzed.expiration,
                isCollectionOffer: fixedFields.isCollectionOffer,
                collectionOfferLimit: fixedFields.collectionOfferLimit,
                creatorOfferNonce: fixedFields.creatorOfferNonce,
                payRoyalties: true,
                marketplaceRecipients: new MarketplaceRecipient[](0)
            });
    }

    function offerStructFromFieldsERC20Payment(
        FuzzedOfferFields memory fuzzed,
        FixedOfferFields memory fixedFields,
        address erc20TokenAddress
    ) internal pure returns (Offer memory offer) {
        offer = offerStructFromFields(fuzzed, fixedFields);
        offer.loanTerms.itemType = ItemType.ERC20;
        offer.loanTerms.token = erc20TokenAddress;
    }

    function offerStructFromFieldsForLending(
        FuzzedOfferFields memory fuzzed,
        FixedOfferFields memory fixedFields
    ) internal view returns (Offer memory) {
        return
        Offer({
                offerType: INiftyApesStructs.OfferType.LENDING,
                collateralItem: CollateralItem({
                    itemType: fixedFields.collateralItemType,
                    token: fixedFields.tokenContractAddress,
                    tokenId: fixedFields.tokenId,
                    amount: fixedFields.tokenAmount
                }),
                loanTerms: LoanTerms({
                    itemType: fixedFields.loanItemType,
                    token: fixedFields.loanTokenAddress,
                    tokenId: 0,
                    principalAmount: fuzzed.principalAmount,
                    minimumPrincipalPerPeriod: fuzzed.minimumPrincipalPerPeriod,
                    downPaymentAmount: 0,
                    periodInterestRateBps: fuzzed.periodInterestRateBps,
                    periodDuration: fuzzed.periodDuration
                }),
                creator: lender1,
                expiration: fuzzed.expiration,
                isCollectionOffer: fixedFields.isCollectionOffer,
                collectionOfferLimit: fixedFields.collectionOfferLimit,
                creatorOfferNonce: fixedFields.creatorOfferNonce,
                payRoyalties: false,
                marketplaceRecipients: new MarketplaceRecipient[](0)
            });
    }

    function saleOfferStructFromFields(
        FuzzedOfferFields memory fuzzed,
        FixedOfferFields memory fixedFields,
        address erc20TokenAddress
    ) internal pure returns (Offer memory) {
        return
            Offer({
                offerType: INiftyApesStructs.OfferType.SALE,
                collateralItem: CollateralItem({
                    itemType: fixedFields.collateralItemType,
                    token: fixedFields.tokenContractAddress,
                    tokenId: fixedFields.tokenId,
                    amount: fixedFields.tokenAmount
                }),
                loanTerms: LoanTerms({
                    itemType: erc20TokenAddress==address(0)? ItemType.NATIVE : ItemType.ERC20,
                    token: erc20TokenAddress,
                    tokenId: 0,
                    principalAmount: 0,
                    minimumPrincipalPerPeriod: 0,
                    downPaymentAmount: fuzzed.downPaymentAmount,
                    periodInterestRateBps: 0,
                    periodDuration: 0
                }),
                creator: fixedFields.creator,
                expiration: fuzzed.expiration,
                isCollectionOffer: fixedFields.isCollectionOffer,
                collectionOfferLimit: fixedFields.collectionOfferLimit,
                creatorOfferNonce: fixedFields.creatorOfferNonce,
                payRoyalties: true,
                marketplaceRecipients: new MarketplaceRecipient[](0)
            });
    }

    function signOffer(uint256 signerPrivateKey, Offer memory offer) public returns (bytes memory) {
        // This is the EIP712 signed hash
        bytes32 offerHash = sellerFinancing.getOfferHash(offer);

        return sign(signerPrivateKey, offerHash);
    }

    function seller1CreateOffer(Offer memory offer) internal returns (bytes memory signature) {
        vm.startPrank(seller1);
        if (offer.collateralItem.itemType == ItemType.ERC721) {
            boredApeYachtClub.approve(address(sellerFinancing), offer.collateralItem.tokenId);
        }
        if (offer.collateralItem.itemType == ItemType.ERC1155) {
            erc1155Token.setApprovalForAll(address(sellerFinancing), true);
        }
        vm.stopPrank();

        return signOffer(seller1_private_key, offer);
    }

    function lender1CreateOffer(Offer memory offer) internal returns (bytes memory signature) {
        vm.startPrank(lender1);
        if (offer.loanTerms.token == WETH_ADDRESS) {
            weth.approve(address(sellerFinancing), offer.loanTerms.principalAmount);
        }
        if (offer.loanTerms.token == USDC_ADDRESS) {
            usdc.approve(address(sellerFinancing), offer.loanTerms.principalAmount);
        }
        vm.stopPrank();

        return signOffer(lender1_private_key, offer);
    }

    function createOfferAndBuyWithSellerFinancing(Offer memory offer) internal returns (uint256 loanId) {
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        loanId = sellerFinancing.buyWithSellerFinancing{ value: offer.loanTerms.downPaymentAmount }(
            offer,
            offerSignature,
            buyer1,
            offer.collateralItem.tokenId,
            offer.collateralItem.amount
        );
        vm.stopPrank();
    }

    function createOfferAndBuyNow(Offer memory offer) internal {
        bytes memory offerSignature = seller1CreateOffer(offer);

        vm.startPrank(buyer1);
        if (offer.loanTerms.itemType == ItemType.NATIVE) {
            sellerFinancing.buyNow{ value: offer.loanTerms.downPaymentAmount }(
                offer,
                offerSignature,
                buyer1,
                offer.collateralItem.tokenId,
                offer.collateralItem.amount
            );
        } else {
            IERC20Upgradeable(offer.loanTerms.token).approve(address(sellerFinancing), offer.loanTerms.downPaymentAmount);
            sellerFinancing.buyNow(
                offer,
                offerSignature,
                buyer1,
                offer.collateralItem.tokenId,
                offer.collateralItem.amount
            );
        }
        vm.stopPrank();
    }

    function mintWeth(address user, uint256 amount) internal {
        IERC20Upgradeable wethToken = IERC20Upgradeable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address wethWhale = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
        vm.startPrank(wethWhale);
        wethToken.transfer(user, amount);
        vm.stopPrank();
    }

    function mintUsdc(address user, uint256 amount) internal {
        address usdcWhale = 0xcEe284F754E854890e311e3280b767F80797180d;
        vm.startPrank(usdcWhale);
        usdc.transfer(user, amount);
        vm.stopPrank();
    }

    function assertionsForExecutedLoan(Offer memory offer, uint256 tokenId, address expectedborrower, uint256 loanId) internal {
        // sellerFinancing contract has NFT
        assertEq(IERC721Upgradeable(offer.collateralItem.token).ownerOf(tokenId), address(sellerFinancing));
        
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(expectedborrower),
                address(sellerFinancing),
                offer.collateralItem.token,
                tokenId
            ),
            true
        );
        // loan auction exists
        Loan memory loan = sellerFinancing.getLoan(loanId);
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId), expectedborrower);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId + 1), offer.creator);

        //buyer tokenId has tokenURI same as original token
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loanId),
            IERC721MetadataUpgradeable(offer.collateralItem.token).tokenURI(tokenId)
        );
        // check loan struct values
        assertEq(loan.loanTerms.principalAmount, offer.loanTerms.principalAmount);
        assertEq(loan.loanTerms.minimumPrincipalPerPeriod, offer.loanTerms.minimumPrincipalPerPeriod);
        assertEq(loan.loanTerms.periodInterestRateBps, offer.loanTerms.periodInterestRateBps);
        assertEq(loan.loanTerms.periodDuration, offer.loanTerms.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.loanTerms.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function assertionsForExecutedLoanERC1155(
        Offer memory offer, uint256 tokenId,
        uint256 tokenAmount,
        address expectedborrower,
        uint256 loanId,
        uint256 totalCollateralBalance
    ) internal {
        // sellerFinancing contract has collateral
        assertEq(IERC1155Upgradeable(offer.collateralItem.token).balanceOf(address(sellerFinancing), tokenId), totalCollateralBalance);

        // loan auction exists
        Loan memory loan = sellerFinancing.getLoan(loanId);
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        assertEq(
            uint(loan.collateralItem.itemType),
            uint(ItemType.ERC1155)
        );
        assertEq(
            loan.collateralItem.token,
            offer.collateralItem.token
        );
        assertEq(
            loan.collateralItem.tokenId,
            tokenId
        );
        assertEq(
            loan.collateralItem.amount,
            tokenAmount
        );
        // buyer NFT minted to buyer
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId), expectedborrower);
        // seller NFT minted to seller
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId + 1), offer.creator);

        //buyer tokenId has tokenURI same as original token
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loanId),
            IERC1155MetadataURIUpgradeable(offer.collateralItem.token).uri(tokenId)
        );
        // check loan struct values
        assertEq(loan.loanTerms.principalAmount, offer.loanTerms.principalAmount);
        assertEq(loan.loanTerms.minimumPrincipalPerPeriod, offer.loanTerms.minimumPrincipalPerPeriod);
        assertEq(loan.loanTerms.periodInterestRateBps, offer.loanTerms.periodInterestRateBps);
        assertEq(loan.loanTerms.periodDuration, offer.loanTerms.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.loanTerms.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function assertionsForClosedLoan(address tokenContractAddress, uint256 tokenId, address expectedNftOwner, uint256 loanId) internal {
        // loan doesn't exist anymore
        Loan memory loan = sellerFinancing.getLoan(loanId);
        assertEq(
            loan.periodBeginTimestamp,
            0
        );
        // expected address has NFT
        assertEq(IERC721Upgradeable(tokenContractAddress).ownerOf(tokenId), expectedNftOwner);

        // require delegate.cash buyer delegation has been revoked
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                address(buyer1),
                address(sellerFinancing),
                tokenContractAddress,
                tokenId
            ),
            false
        );

        
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId), address(0));
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId+1), address(0));
    }

    function assertionsForExecutedLoanThrough3rdPartyLender(Offer memory offer, uint256 tokenId, address expectedborrower, uint256 loanId) internal {
        // sellerFinancing contract has NFT
        assertEq(IERC721Upgradeable(offer.collateralItem.token).ownerOf(tokenId), address(sellerFinancing));
        // require delegate.cash has buyer delegation
        assertEq(
            IDelegationRegistry(mainnetDelegateRegistryAddress).checkDelegateForToken(
                expectedborrower,
                address(sellerFinancing),
                offer.collateralItem.token,
                tokenId
            ),
            true
        );
        Loan memory loan = sellerFinancing.getLoan(loanId);
        assertEq(
            loan.periodBeginTimestamp,
            block.timestamp
        );
        // borrower NFT minted to borrower1
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId), expectedborrower);
        // lender NFT minted to lender1
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId + 1), offer.creator);
        
        //buyer tokenId has tokenURI same as original token
        assertEq(
            IERC721MetadataUpgradeable(address(sellerFinancing)).tokenURI(loanId),
            IERC721MetadataUpgradeable(offer.collateralItem.token).tokenURI(tokenId)
        );

        // check loan struct values
        assertEq(loan.loanTerms.principalAmount, offer.loanTerms.principalAmount);
        assertEq(loan.loanTerms.minimumPrincipalPerPeriod, offer.loanTerms.minimumPrincipalPerPeriod);
        assertEq(loan.loanTerms.periodInterestRateBps, offer.loanTerms.periodInterestRateBps);
        assertEq(loan.loanTerms.periodDuration, offer.loanTerms.periodDuration);
        assertEq(loan.periodEndTimestamp, block.timestamp + offer.loanTerms.periodDuration);
        assertEq(loan.periodBeginTimestamp, block.timestamp);
    }

    function assertionsForClosedLoanERC1155(address tokenContractAddress, uint256 tokenId, uint256 loanId) internal {
        // loan doesn't exist anymore
        Loan memory loan = sellerFinancing.getLoan(loanId);
        assertEq(
            loan.periodBeginTimestamp,
            0
        );
        // sellerfinancing address doesn't have collateral
        assertEq(IERC1155Upgradeable(tokenContractAddress).balanceOf(address(sellerFinancing), tokenId), 0);
        
        // buyer NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId), address(0));
        // seller NFT burned
        vm.expectRevert("ERC721: invalid token ID");
        assertEq(IERC721Upgradeable(address(sellerFinancing)).ownerOf(loanId+1), address(0));
    }
}
