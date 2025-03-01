// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow escrow;

    address private BOB;
    address private ALICE;
    address private ARBITRATOR;

    uint256 private constant AMOUNT = 1 ether;

    function setUp() public {
        escrow = new Escrow();

        // Assign addresses dynamically using vm.addr() during test execution
        BOB = vm.addr(1);
        ALICE = vm.addr(2);
        ARBITRATOR = vm.addr(3);

        // Fund the addresses (Bob, Alice, and Arbitrator) with some ether
        deal(BOB, 10 ether);
        deal(ALICE, 10 ether);
        deal(ARBITRATOR, 10 ether);
    }

    function test_newAgreement() public {
        // Test creating a new agreement

        vm.prank(ARBITRATOR);
        uint256 agreementId = escrow.newAgreement(BOB, ALICE, AMOUNT);

        // Destructure the returned values into the agreement struct
        (address bob, address alice, address arbitrator, uint256 amount, bool bobIn, bool aliceIn) = escrow.agreements(agreementId);
        Escrow.Agreement memory agreement = Escrow.Agreement(bob, alice, arbitrator, amount, bobIn, aliceIn);

        assertEq(agreement.bob, BOB, "Bob should be the buyer");
        assertEq(agreement.alice, ALICE, "Alice should be the seller");
        assertEq(agreement.arbitrator, ARBITRATOR, "Arbitrator should be the correct address");
        assertEq(agreement.amount, AMOUNT, "Amount should be the correct one");
        assertFalse(agreement.bobIn, "Bob should not have deposited yet");
        assertFalse(agreement.aliceIn, "Alice should not have deposited yet");
    }

    function test_deposit() public {
        // Create agreement
        vm.prank(ARBITRATOR);
        uint256 agreementId = escrow.newAgreement(BOB, ALICE, AMOUNT);

        // Bob deposits the amount
        vm.prank(BOB);
        escrow.deposit{value: AMOUNT}(agreementId);

        // Alice deposits the amount
        vm.prank(ALICE);
        escrow.deposit{value: AMOUNT}(agreementId);


        // Destructure the returned values into the agreement struct
        (address bob, address alice, address arbitrator, uint256 amount, bool bobIn, bool aliceIn) = escrow.agreements(agreementId);
        Escrow.Agreement memory agreement = Escrow.Agreement(bob, alice, arbitrator, amount, bobIn, aliceIn);

        // Check that Bob has deposited
        assertTrue(agreement.bobIn, "Bob should have deposited");

        // Check that Alice has deposited
        assertTrue(agreement.aliceIn, "Alice should have deposited");
    }

    function test_refund() public {
        // Create agreement
        uint256 agreementId = escrow.newAgreement(BOB, ALICE, AMOUNT);

        // Bob deposits the amount
        vm.prank(BOB);
        escrow.deposit{value: AMOUNT}(agreementId);

        // Alice deposits the amount
        vm.prank(ALICE);
        escrow.deposit{value: AMOUNT}(agreementId);

        // Refund Bob
        uint256 initialBobBalance = BOB.balance;
        vm.prank(BOB);
        escrow.refund(agreementId);

        // Ensure Bob got refunded
        assertEq(BOB.balance, initialBobBalance + AMOUNT, "Bob should be refunded");

        // Refund Alice
        uint256 initialAliceBalance = ALICE.balance;
        vm.prank(ALICE);
        escrow.refund(agreementId);

        // Ensure Alice got refunded
        assertEq(ALICE.balance, initialAliceBalance + AMOUNT, "Alice should be refunded");
    }

    function test_completeAgreementToBob() public {
        // Create agreement
        vm.prank(ARBITRATOR);
        uint256 agreementId = escrow.newAgreement(BOB, ALICE, AMOUNT);

        // Bob deposits the amount
        vm.prank(BOB);
        escrow.deposit{value: AMOUNT}(agreementId);

        // Alice deposits the amount
        vm.prank(ALICE);
        escrow.deposit{value: AMOUNT}(agreementId);

        // Complete the agreement in favor of Bob
        vm.prank(ARBITRATOR);
        escrow.complete(agreementId, BOB);

        // Destructure the returned values into the agreement struct
        (address bob, address alice, address arbitrator, uint256 amount, bool bobIn, bool aliceIn) = escrow.agreements(agreementId);
        Escrow.Agreement memory agreement = Escrow.Agreement(bob, alice, arbitrator, amount, bobIn, aliceIn);

        // Ensure Bob got the full amount
        assertFalse(agreement.bobIn, "Bob should not have anything left in the agreement");
        assertFalse(agreement.aliceIn, "Alice should not have anything left in the agreement");

        // Check if Bob has received the funds
        uint256 finalBobBalance = BOB.balance;
        assertGt(finalBobBalance, AMOUNT, "Bob should have received funds");
    }

    function test_completeAgreementToAlice() public {
        // Create another agreement for Alice
        vm.prank(ARBITRATOR);
        uint256 newAgreementId = escrow.newAgreement(BOB, ALICE, AMOUNT);

        // Bob and Alice both deposit the amount
        vm.prank(BOB);
        escrow.deposit{value: AMOUNT}(newAgreementId);

        vm.prank(ALICE);
        escrow.deposit{value: AMOUNT}(newAgreementId);

        // Complete the agreement in favor of Alice
        vm.prank(ARBITRATOR);
        escrow.complete(newAgreementId, ALICE);

        // Destructure the returned values into the new agreement struct
        (address newBob, address newAlice, address newArbitrator, uint256 newAmount, bool newBobIn, bool newAliceIn) = escrow.agreements(newAgreementId);
        Escrow.Agreement memory newAgreement = Escrow.Agreement(newBob, newAlice, newArbitrator, newAmount, newBobIn, newAliceIn);

        // Ensure Alice got the full amount
        assertFalse(newAgreement.bobIn, "Bob should not have anything left in the agreement");
        assertFalse(newAgreement.aliceIn, "Alice should not have anything left in the agreement");

        // Check if Alice has received the funds
        uint256 finalAliceBalance = ALICE.balance;
        assertGt(finalAliceBalance, AMOUNT, "Alice should have received funds");
    }
}
