// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffel} from "../../script/DeployRaffel.s.sol";
import {Raffel} from "../../src/Raffel.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffelTest is Test {
    Raffel raffel;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    uint256 automationUpdateInterval;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;
    uint256 deployerKey;

    event EnteredRaffel(address indexed participant);

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        DeployRaffel deployRaffel = new DeployRaffel();
        (raffel, helperConfig) = deployRaffel.run();

        (
            ,
            gasLane,
            automationUpdateInterval,
            entranceFee,
            callbackGasLimit,
            vrfCoordinator, // link
            // deployerKey
            ,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffelInitializesInOpenState() public view {
        assert(raffel.getRaffelState() == Raffel.RaffelState.OPEN);
    }

    //////////////////////////
    // Enter Raffel //
    //////////////////////////

    function testRaffelRevertWhenYouDontPayEnough() public {
        // Arrange
        // Act
        // Assert
        vm.prank(PLAYER);
        vm.expectRevert(Raffel.Raffel__NotEnoughEthSent.selector);
        raffel.enterRaffle();
    }

    function testRaffelRecordWhenPlayerEnters() public {
        // Arrange
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
        // Act
        address playerRecorded = raffel.getParticipant(0);
        // Assert

        assert(playerRecorded == PLAYER);
    }

    function testEventEmitsOnEnterRaffel() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffel));
        emit EnteredRaffel(PLAYER);
        // Act
        raffel.enterRaffle{value: entranceFee}();
        // Assert
    }

    function testCantEnterRaffelWhileCalculating() public {
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffel.performUpkeep("");
        vm.expectRevert(Raffel.Raffel__RaffelNotOpen.selector);
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
        (bool isTrue, ) = raffel.checkUpkeep("");
        assert(!isTrue);
    }

    function testCheckUpKeepReturnsTrueIfEnoughTimeHasPassed() public {
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        (bool isTrue, ) = raffel.checkUpkeep("");
        assert(isTrue);
    }

    /////////////////////
    // Perform Upkeep //
    /////////////////////

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffel.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 contractBalance = 0;
        uint256 participants = 0;
        uint256 raffelState = 0;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffel.Raffel__UpkeepNotNeeded.selector,
                contractBalance,
                participants,
                raffelState
            )
        );
        raffel.performUpkeep("");
    }

    modifier raffelEnteredAndTimePassed() {
        // Arrange
        vm.prank(PLAYER);
        raffel.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpKeepUpdatesRaffelStateAndEmmitsRequestId()
        public
        raffelEnteredAndTimePassed
    {
        // Act / Assert
        vm.recordLogs();
        raffel.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2);
        assertEq(entries[0].topics.length, 4);
        assertEq(
            entries[0].topics[0],
            keccak256(
                "RandomWordsRequested(bytes32,uint256,uint256,uint64,uint16,uint32,uint32,address)"
            )
        );
        assertEq(
            entries[1].topics[0],
            keccak256("RequestedRaffelWinner(uint256)")
        );
    }

    /////////////////////////////
    /// fullfillRandomWords ///
    /////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFullfillRandomWordsCanbeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffelEnteredAndTimePassed skipFork {
        // Arrange
        vm.expectRevert("nonexistent request");
        // Act
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffel)
        );
    }

    function testFullfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffelEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalEntries = 5;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i <= additionalEntries; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffel.enterRaffle{value: entranceFee}();
        }

        console.log("contract balance:", address(raffel).balance);
        console.log("participants count:", raffel.getParticipentsCount());

        uint256 startingTimeStamp = raffel.getRecentTimestamp();
        uint256 finalRaffelAmount = (additionalEntries + 1) * entranceFee;
        uint256 winnerStartingBalance = address(uint160(5)).balance;

        vm.recordLogs();
        raffel.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffel)
        );

        uint256 endingTimeStamp = raffel.getRecentTimestamp();

        assert(raffel.getRaffelState() == Raffel.RaffelState.OPEN);
        assert(raffel.getParticipentsCount() == 0);
        address winner = raffel.getWinner();
        assert(winner != address(0));
        assert(endingTimeStamp > startingTimeStamp);
        assert(winner.balance != 0);

        assert(winner.balance == finalRaffelAmount + winnerStartingBalance);
        console.log("winner balance:", winner.balance);
        console.log("winner starting balance:", winnerStartingBalance);
        console.log("final raffel amount:", finalRaffelAmount);
    }
}
