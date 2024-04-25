// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffel} from "../src/Raffel.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffel is Script {
    function run() external returns (Raffel, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subscriptionId,
            bytes32 gasLane,
            uint256 automationUpdateInterval,
            uint256 raffleEntranceFee,
            uint32 callbackGasLimit,
            address vrfCoordinator,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // we need to create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (subscriptionId, vrfCoordinator) = createSubscription
                .createSubscription(vrfCoordinator, deployerKey);

            // Fund Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                linkToken,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        Raffel raffel = new Raffel(
            subscriptionId,
            gasLane,
            automationUpdateInterval,
            raffleEntranceFee,
            callbackGasLimit,
            vrfCoordinator
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffel),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );

        return (raffel, helperConfig);
    }
}
