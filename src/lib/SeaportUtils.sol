//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../interfaces/seaport/ISeaport.sol";
import "../interfaces/sellerFinancing/ISellerFinancing.sol";

/// @title Moves the Seaport utils functions implementation into a separate library to save
///        code size in the main contract.
library SeaportUtils {
    function getOrderHash(
        address seaportContractAddress,
        ISeaport.Order memory order
    ) external view returns (bytes32 orderHash) {
        // Derive order hash by supplying order parameters along with counter.
        orderHash = ISeaport(seaportContractAddress).getOrderHash(
            ISeaport.OrderComponents(
                order.parameters.offerer,
                order.parameters.zone,
                order.parameters.offer,
                order.parameters.consideration,
                order.parameters.orderType,
                order.parameters.startTime,
                order.parameters.endTime,
                order.parameters.zoneHash,
                order.parameters.salt,
                order.parameters.conduitKey,
                ISeaport(seaportContractAddress).getCounter(
                    order.parameters.offerer
                )
            )
        );
    }

    function constructOrder(
        ISellerFinancing.SeaportUtilvalues memory values,
        address nftContractAddress,
        uint256 nftId,
        uint256 listingPrice,
        uint256 seaportFeeAmount,
        uint256 listingStartTime,
        uint256 listingEndTime,
        address asset,
        uint256 randomSalt
    ) external view returns (ISeaport.Order[] memory order) {
        ISeaport.ItemType considerationItemType = (
            asset == address(0)
                ? ISeaport.ItemType.NATIVE
                : ISeaport.ItemType.ERC20
        );
        address considerationToken = (asset == address(0) ? address(0) : asset);

        order = new ISeaport.Order[](1);
        order[0] = ISeaport.Order({
            parameters: ISeaport.OrderParameters({
                offerer: address(this),
                zone: values.seaportZone,
                offer: new ISeaport.OfferItem[](1),
                consideration: new ISeaport.ConsiderationItem[](2),
                orderType: ISeaport.OrderType.FULL_OPEN,
                startTime: listingStartTime,
                endTime: listingEndTime,
                zoneHash: values.seaportZoneHash,
                salt: randomSalt,
                conduitKey: values.seaportConduitKey,
                totalOriginalConsiderationItems: 2
            }),
            signature: bytes("")
        });
        order[0].parameters.offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: nftContractAddress,
            identifierOrCriteria: nftId,
            startAmount: 1,
            endAmount: 1
        });
        order[0].parameters.consideration[0] = ISeaport.ConsiderationItem({
            itemType: considerationItemType,
            token: considerationToken,
            identifierOrCriteria: 0,
            startAmount: listingPrice - seaportFeeAmount,
            endAmount: listingPrice - seaportFeeAmount,
            recipient: payable(address(this))
        });
        order[0].parameters.consideration[1] = ISeaport.ConsiderationItem({
            itemType: considerationItemType,
            token: considerationToken,
            identifierOrCriteria: 0,
            startAmount: seaportFeeAmount,
            endAmount: seaportFeeAmount,
            recipient: payable(values.seaportFeeRecepient)
        });
    }

    function requireValidOrderAssets(
        ISeaport.Order memory order,
        address nftContractAddress,
        uint256 nftId,
        address loanAsset,
        address wethContractAddress
    ) external view {
        require(
            order.parameters.consideration[0].itemType ==
                ISeaport.ItemType.ERC721,
            "00067"
        );
        require(
            order.parameters.consideration[0].token == nftContractAddress,
            "00067"
        );
        require(
            order.parameters.consideration[0].identifierOrCriteria == nftId,
            "00067"
        );
        require(
            order.parameters.offer[0].itemType == ISeaport.ItemType.ERC20,
            "00067"
        );
        require(
            order.parameters.consideration[1].itemType ==
                ISeaport.ItemType.ERC20,
            "00067"
        );
        if (loanAsset == address(0)) {
            require(
                order.parameters.offer[0].token == wethContractAddress,
                "00067"
            );
            require(
                order.parameters.consideration[1].token == wethContractAddress,
                "00067"
            );
        } else {
            require(order.parameters.offer[0].token == loanAsset, "00067");
            require(
                order.parameters.consideration[1].token == loanAsset,
                "00067"
            );
        }
    }
}
