//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../interfaces/niftyapes/INiftyApesStructs.sol";

/// @title Storage contract for first facet SellerFinancingFacet
/// @custom:version 2.0
/// @author zishansami102 (zishansami.eth)
/// @custom:contributor captnseagraves (captnseagraves.eth)
/// @custom:contributor zjmiller (zjmiller.eth)
library NiftyApesStorage {
    /// @dev Internal constant address for the Chainalysis OFAC sanctions oracle
    address constant SANCTIONS_CONTRACT = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    /// @notice The base value for fees in the protocol.
    uint256 constant BASE_BPS = 10_000;

    /// @dev Constant typeHash for EIP-712 hashing of Offer struct
    bytes32 constant _OFFER_TYPEHASH =
        keccak256(
            "Offer(uint128 price,uint32 creatorOfferNonce,uint128 downPaymentAmount,uint128 minimumPrincipalPerPeriod,uint256 nftId,address nftContractAddress,address creator,uint32 periodInterestRateBps,uint32 periodDuration,uint32 expiration,bool isCollectionOffer,uint64 collectionOfferLimit)"
        );

    bytes32 constant SELLER_FINANCING_STORAGE_POSITION =
        keccak256("diamond.standard.seller.financing");

    struct SellerFinancingStorage {
        // slot values given below are relative the actual slot position determined by the slot for `SELLER_FINANCING_STORAGE_POSITION`

        // increments by two for each loan, once for borrowerNftId, once for lenderNftId
        /// slot0
        uint256 loanNftNonce;
        /// @dev The stored address for the royalties engine
        /// slot1
        address royaltiesEngineContractAddress;
        /// @dev The stored address for the delegate registry contract
        /// slot2
        address delegateRegistryContractAddress;
        /// @dev The stored address for the seaport contract
        /// slot3
        address seaportContractAddress;
        /// @dev The stored address for the weth contract
        /// slot4
        address wethContractAddress;
        /// @dev The status of sanctions checks
        /// slot4
        bool sanctionsPause;
        /// @dev A mapping for a NFT to a loan .
        ///      The mapping has to be broken into two parts since an NFT is denominated by its address (first part)
        ///      and its nftId (second part) in our code base.
        /// slot5
        mapping(address => mapping(uint256 => INiftyApesStructs.Loan)) loans;
        /// @dev A mapping for a Seller Financing Ticket to an underlying NFT Asset .
        ///      This mapping enables the protocol to query a loan by Seller Financing Ticket Id.
        /// slot6
        mapping(uint256 => INiftyApesStructs.UnderlyingNft) underlyingNfts;
        /// @dev A mapping for a signed offer to a collection offer counter
        /// slot7
        mapping(bytes => uint64) collectionOfferCounters;
        /// @dev A mapping to mark a signature as used.
        ///      The mapping allows users to withdraw offers that they made by signature.
        /// slot8
        mapping(bytes => bool) cancelledOrFinalized;
        /// @dev A mapping to store a unique offer nonce value for each user.
        ///      The mapping allows users to withdraw all offers at once by just incrementing the nonce
        /// slot9
        mapping(address => uint32) offerNonce;
    }

    function sellerFinancingStorage() internal pure returns (SellerFinancingStorage storage sf) {
        bytes32 position = SELLER_FINANCING_STORAGE_POSITION;
        assembly {
            sf.slot := position
        }
    }
}
