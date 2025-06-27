// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

interface MintableToken {
    function mint(address, uint256) external;
}

contract OurTokenTest is Test, ZkSyncChainChecker {
    uint256 BOB_STARTING_AMOUNT = 100 ether;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether; // 1 million tokens with 18 decimal places

    OurToken public ourToken;
    DeployOurToken public deployer;
    address public deployerAddress;
    address bob;
    address alice;

    function setUp() public {
        deployer = new DeployOurToken();
        if (!isZkSyncChain()) {
            ourToken = deployer.run();
        } else {
            ourToken = new OurToken(INITIAL_SUPPLY);
            ourToken.transfer(msg.sender, INITIAL_SUPPLY);
        }

        bob = makeAddr("bob");
        alice = makeAddr("alice");

        vm.prank(msg.sender);
        ourToken.transfer(bob, BOB_STARTING_AMOUNT);
    }

    function testBobBalance() public view {
        uint256 bobTokenBalance = ourToken.balanceOf(bob);
        assertEq(bobTokenBalance, BOB_STARTING_AMOUNT);
    }

    function testInitialSupply() public view {
        assertEq(ourToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    function testUsersCantMint() public {
        vm.expectRevert();
        MintableToken(address(ourToken)).mint(address(this), 1);
    }

    function testAllowances() public {
        uint256 initialAllowance = 1000;

        // Bob approves Alice to spend tokens on his behalf

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);
        uint256 transferAmount = 500;

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);
        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), BOB_STARTING_AMOUNT - transferAmount);
    }

    // can you get the coverage up?

    // ────────────────────────────────────────────────────────────────────
    // EXTRA TESTS – transfer, allowance, edge-cases, owner-only mint
    // ────────────────────────────────────────────────────────────────────

    /* ---------------------------------------------------------- */
    /*               TRANSFERS                                    */
    /* ---------------------------------------------------------- */

    function testDirectTransfer() public {
        uint256 sendAmount = 20 ether;

        // Bob → Alice
        vm.prank(bob);
        ourToken.transfer(alice, sendAmount);

        assertEq(ourToken.balanceOf(bob), BOB_STARTING_AMOUNT - sendAmount);
        assertEq(ourToken.balanceOf(alice), sendAmount);
    }

    function testTransferExceedingBalanceShouldFail() public {
        uint256 tooMuch = BOB_STARTING_AMOUNT + 1;

        vm.prank(bob);
        vm.expectRevert(); // “ERC20: transfer amount exceeds balance”
        ourToken.transfer(alice, tooMuch);
    }

    function testTransferToZeroAddressShouldFail() public {
        vm.prank(bob);
        vm.expectRevert(); // “ERC20: transfer to the zero address”
        ourToken.transfer(address(0), 1 ether);
    }

    /* ---------------------------------------------------------- */
    /*               ALLOWANCES                                   */
    /* ---------------------------------------------------------- */

    function testApproveAndAllowance() public {
        uint256 allowanceAmt = 1_000 ether;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmt);

        assertEq(ourToken.allowance(bob, alice), allowanceAmt);
    }

    function testTransferFromWithoutApprovalReverts() public {
        vm.prank(alice);
        vm.expectRevert(); // “ERC20: insufficient allowance”
        ourToken.transferFrom(bob, alice, 1 ether);
    }

    function testApproveZeroAddressShouldFail() public {
        vm.prank(bob);
        vm.expectRevert(); // “ERC20: approve to the zero address”
        ourToken.approve(address(0), 100);
    }

    /* ---------------------------------------------------------- */
    /*               OWNER-ONLY MINT GUARD                        */
    /* ---------------------------------------------------------- */

    function testMintOnlyOwner() public {
        // Non-owner tries to mint → revert
        vm.prank(bob);
        vm.expectRevert();
        MintableToken(address(ourToken)).mint(bob, 1 ether);
    }
}
