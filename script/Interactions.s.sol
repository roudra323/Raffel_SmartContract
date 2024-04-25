// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64, address) {
        HelperConfig helperConfig = new HelperConfig();
        (, , , , , address vrfCoordinator, , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64, address) {
        console.log("Creating Subscription for chain id: ", block.chainid);

        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() external returns (uint64, address) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 1 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subscriptionId,
            ,
            ,
            ,
            ,
            address vrfCoordinator,
            address linkAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint64 updatedSubId, address updatedVRFv2) = createSub.run();
            subscriptionId = updatedSubId;
            vrfCoordinator = updatedVRFv2;
            console.log(
                "New SubId Created! ",
                subscriptionId,
                "VRF Address: ",
                vrfCoordinator
            );
        }
        fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkAddress,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address linkAddress,
        uint256 deployerKey
    ) public {
        console.log(
            "Funding Subscription for subscriptionId: ",
            subscriptionId
        );
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using linkAddress: ", linkAddress);
        console.log("On chainID: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(linkAddress).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(linkAddress).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(linkAddress).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffel,
        address vrfCoordinator,
        uint64 subscriptionId,
        uint256 deployerKey
    ) public {
        console.log("Adding Consumer for raffel: ", raffel);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using subscriptionId: ", subscriptionId);
        console.log("On chainID: ", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            raffel
        );
        vm.stopBroadcast();
    }

    function addConsumerUsinfConfig(address raffel) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subscriptionId,
            ,
            ,
            ,
            ,
            address vrfCoordinator,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        addConsumer(raffel, vrfCoordinator, subscriptionId, deployerKey);
    }

    function run() public {
        address raffel = DevOpsTools.get_most_recent_deployment(
            "Raffel",
            block.chainid
        );
        addConsumerUsinfConfig(raffel);
    }
}
