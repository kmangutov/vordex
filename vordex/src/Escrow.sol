// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Escrow {
    struct Agreement {
        address bob;
        address alice;
        address arbitrator;
        uint256 amount;
        bool bobIn;
        bool aliceIn;
    }

    mapping(uint256 => Agreement) public agreements;
    uint256 public agreementCount;

    function newAgreement(address _bob, address _alice, uint256 _amount) public returns (uint256) {
        uint256 agreementId = agreementCount++;
        agreements[agreementId] = Agreement({
            bob: _bob,
            alice: _alice,
            arbitrator: msg.sender, // For simplicity, the caller is the arbitrator
            amount: _amount,
            bobIn: false,
            aliceIn: false
        });
        return agreementId;
    }

    function deposit(uint256 agreementId) public payable {
        Agreement storage agreement = agreements[agreementId];

        require(msg.sender == agreement.bob || msg.sender == agreement.alice, "Only involved parties can deposit");

        if (msg.sender == agreement.bob) {
            agreement.bobIn = true;
        } else if (msg.sender == agreement.alice) {
            agreement.aliceIn = true;
        }
    }

    function refund(uint256 agreementId) public {
        Agreement storage agreement = agreements[agreementId];

        require(msg.sender == agreement.bob || msg.sender == agreement.alice, "Only involved parties can refund");

        if (msg.sender == agreement.bob) {
            payable(agreement.bob).transfer(agreement.amount);
            agreement.bobIn = false;
        } else if (msg.sender == agreement.alice) {
            payable(agreement.alice).transfer(agreement.amount);
            agreement.aliceIn = false;
        }
    }

    function complete(uint256 agreementId, address winner) public {
        Agreement storage agreement = agreements[agreementId];

        require(msg.sender == agreement.arbitrator, "Only arbitrator can complete the agreement");

        if (winner == agreement.bob) {
            payable(agreement.bob).transfer(agreement.amount * 2); // Send the full amount to Bob
        } else if (winner == agreement.alice) {
            payable(agreement.alice).transfer(agreement.amount * 2); // Send the full amount to Alice
        }

        agreement.bobIn = false;
        agreement.aliceIn = false;
    }
}
