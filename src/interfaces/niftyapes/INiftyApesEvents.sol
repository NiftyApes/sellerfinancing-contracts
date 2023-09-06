//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./INiftyApesStructs.sol";

/// @title Events emitted by the protocol.
interface INiftyApesEvents {
    /// @notice Emitted when a offer signature gets has been used
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The token id, this field can be meaningless if the offer is a floor term offer
    /// @param offer The offer details
    /// @param signature The signature that has been revoked
    event OfferSignatureUsed(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        INiftyApesStructs.Offer offer,
        bytes signature
    );

    /// @notice Emitted when a new loan is executed
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The token id
    /// @param signature The signature that has been used
    /// @param loan The loan details
    event LoanExecuted(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        uint256 indexed tokenAmount,
        bytes signature,
        INiftyApesStructs.Loan loan
    );

    /// @notice Emitted when a payment is made toward the loan
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The token id
    /// @param amount The total amount received
    /// @param protocolFee The amount paid as protocol fee
    /// @param totalRoyaltiesPaid The amount paid in royalties
    /// @param interestPaid the amount paid in interest
    /// @param loan The loan details
    event PaymentMade(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 protocolFee,
        uint256 totalRoyaltiesPaid,
        uint256 interestPaid,
        INiftyApesStructs.Loan loan
    );

    /// @notice Emitted when a loan is fully repaid
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The token id
    /// @param loan The loan details
    event LoanRepaid(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        INiftyApesStructs.Loan loan
    );

    /// @notice Emitted when an asset is seized
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The token id
    /// @param loan The loan details
    event AssetSeized(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        INiftyApesStructs.Loan loan
    );

    /// @notice Emitted when an NFT is sold instantly on Seaport
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The tokenId of the NFT which was put as collateral
    /// @param saleAmount The sale value
    event InstantSell(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        uint256 saleAmount
    );

    /// @notice Emitted when an locked NFT is listed for sale through Seaport
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The tokenId of the listed NFT
    /// @param orderHash The hash of the order which listed the NFT
    /// @param loan The loan details at the time of listing
    event ListedOnSeaport(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        bytes32 indexed orderHash,
        INiftyApesStructs.Loan loan
    );

    /// @notice Emitted when a seaport NFT listing thorugh NiftyApes is cancelled by the borrower
    /// @param tokenContractAddress The token contract address
    /// @param tokenId The tokenId of the listed NFT
    /// @param orderHash The hash of the order which listed the NFT
    /// @param loan The loan details at the time of listing
    event ListingCancelledSeaport(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        bytes32 indexed orderHash,
        INiftyApesStructs.Loan loan
    );

    /// @notice Emitted when a flashClaim is executed on an NFT
    /// @param tokenContractAddress The address of the NFT collection
    /// @param tokenId The id of the specified NFT
    /// @param receiverAddress The address of the external contract that will receive and return the token
    event FlashClaim(address tokenContractAddress, uint256 tokenId, address receiverAddress);

    /// @notice Emitted when a buyNow sale is executed on an offer
    /// @param tokenContractAddress The address of the offered token
    /// @param tokenId The id of the offered token
    /// @param tokenAmount The offered amount
    /// @param paymentToken The address of the payment token
    /// @param paymentAmount The ask amount
    event SaleExecuted(
        address indexed tokenContractAddress,
        uint256 indexed tokenId,
        uint256 indexed tokenAmount,
        address paymentToken,
        uint256 paymentAmount
    );

    /// @notice Emitted when a fee amount is paid to the marketplace address
    /// @param offerSignature The offer signature
    /// @param marketplace The address of the marketplace
    /// @param feeToken the address of the fee token
    /// @param feeAmount The fee amount paid
    event MarketplaceFeesPaid(
        bytes indexed offerSignature,
        address indexed marketplace,
        address indexed feeToken,
        uint256 feeAmount
    );
}
