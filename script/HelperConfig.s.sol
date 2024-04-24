// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 public constant ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 11357, // have to update this
                callbackGasLimit: 100000,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 BASE_FEE = 0.1 ether; // 0.1 LINK
        uint96 GAS_PRICE_LINK = 1e9; // 1 gwei

        LinkToken linkToken = new LinkToken();

        vm.startBroadcast();

        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );

        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.1 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorMock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, // have to update this
                callbackGasLimit: 500000,
                linkToken: address(linkToken),
                deployerKey: ANVIL_PRIVATE_KEY
            });
    }
}
