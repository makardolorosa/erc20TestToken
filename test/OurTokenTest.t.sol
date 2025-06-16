// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 1000 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        // Fund Bob with some tokens
        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobInitialBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testDirectTransfer() public {
        uint256 transferAmount = 100 ether;

        vm.prank(bob);
        ourToken.transfer(alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }

    function testTransferFailsWithoutEnoughBalance() public {
        uint256 transferAmount = 100 ether;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                0,
                transferAmount
            )
        ); // Alice has 0 tokens
        //vm.expectRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        ourToken.transfer(bob, transferAmount);
    }

    function testApproveAndTransferFrom() public {
        uint256 approveAmount = 200 ether;
        uint256 transferAmount = 150 ether;

        vm.prank(bob);
        ourToken.approve(alice, approveAmount);

        vm.prank(alice);
        ourToken.transferFrom(bob, charlie, transferAmount);

        assertEq(ourToken.balanceOf(charlie), transferAmount);
        assertEq(
            ourToken.allowance(bob, alice),
            approveAmount - transferAmount
        );
    }

    function testTransferFromFailsWithoutApproval() public {
        uint256 transferAmount = 100 ether;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                alice,
                0,
                transferAmount
            )
        );
        //vm.expectRevert(IERC20Errors.ERC20InsufficientAllowance.selector);
        ourToken.transferFrom(bob, charlie, transferAmount);
    }

    function testTransferFromFailsWithoutBalance() public {
        // Approve but don't fund bob
        vm.prank(bob);
        ourToken.approve(alice, 100 ether);

        // Remove bob's balance
        vm.prank(bob);
        ourToken.transfer(charlie, STARTING_BALANCE);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                bob,
                0,
                100 ether
            )
        );
        ourToken.transferFrom(bob, charlie, 100 ether);
    }

    function testIncreaseAndDecreaseAllowance() public {
        vm.prank(bob);
        ourToken.approve(alice, 100 ether);

        vm.prank(bob);
        ourToken.increaseAllowance(alice, 50 ether);
        assertEq(ourToken.allowance(bob, alice), 150 ether);

        vm.prank(bob);
        ourToken.decreaseAllowance(alice, 20 ether);
        assertEq(ourToken.allowance(bob, alice), 130 ether);
    }

    function testCannotDecreaseAllowanceBelowZero() public {
        vm.prank(bob);
        ourToken.approve(alice, 10 ether);

        vm.prank(bob);
        vm.expectRevert("ERC20: decreased allowance below zero");
        ourToken.decreaseAllowance(alice, 20 ether);
    }

    function testApproveEmitsEvent() public {
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, 123 ether);
        ourToken.approve(alice, 123 ether);
    }

    function testTransferEmitsEvent() public {
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, 50 ether);
        ourToken.transfer(alice, 50 ether);
    }

    // Needed to emit events manually for expectEmit checks
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
}
