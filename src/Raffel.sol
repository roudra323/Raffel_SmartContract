// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Raffel
 * @author roudra323
 * @notice This contract is for creating a raffel
 * @dev Implements chainlink VRF for random number generation
 */
contract Raffel is VRFConsumerBaseV2 {
    error Raffel__NotEnoughEthSent();
    error Raffel__TransferFailed();
    error Raffel__RaffelNotOpen();
    error Raffel__UpkeepNotNeeded(
        uint256 balance,
        uint256 participants,
        uint256 raffelState
    );

    /**
     * Type Declarations
     */
    enum RaffelState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 2;
    uint32 private constant NUM_OF_WORDS = 1;

    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private immutable i_interval;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_gasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_participants;
    address private s_recentWinner;
    RaffelState private s_raffelState;

    /**
     * Events
     */
    event EnteredRaffel(address indexed participant);
    event WinnerPicked(address indexed winner);
    event RequestedRaffelWinner(uint256 indexed requestId);

    constructor(
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_gasLimit = callbackGasLimit;
        s_raffelState = RaffelState.OPEN;
    }

    function enterRaffle() public payable {
        // Check if raffel is open
        if (s_raffelState != RaffelState.OPEN) {
            revert Raffel__RaffelNotOpen();
        }
        // Enter the raffle
        if (msg.value < i_entranceFee) {
            revert Raffel__NotEnoughEthSent();
        }
        s_participants.push(payable(msg.sender));
        emit EnteredRaffel(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Automation nodes call to see
     * if it's time to perform the upkeep.
     * The following should be true for this to return true:
     * 1. The raffel is open
     * 2. The interval has passed
     * 3. There are participants in the raffel
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = RaffelState.OPEN == s_raffelState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);

        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool success, ) = checkUpkeep("");
        if (!success) {
            revert Raffel__UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                uint256(s_raffelState)
            );
        }
        // Pick the winner
        // if (block.timestamp - s_lastTimeStamp < i_interval) {
        //     revert();
        // }

        s_raffelState = RaffelState.CALCULATING;

        console.log("This is the  before ");
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_gasLimit,
            NUM_OF_WORDS
        );
        console.log("This is the  after ");

        emit RequestedRaffelWinner(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /*_requestId */
        uint256[] memory _randomWords
    ) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_participants.length;
        address payable winner = s_participants[indexOfWinner];
        s_recentWinner = winner;
        s_raffelState = RaffelState.OPEN;

        // Resetting the array
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffelState() public view returns (RaffelState) {
        return s_raffelState;
    }

    function getParticipant(uint256 index) public view returns (address) {
        return s_participants[index];
    }

    function getParticipentsCount() public view returns (uint256) {
        return s_participants.length;
    }

    function getWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRecentTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
