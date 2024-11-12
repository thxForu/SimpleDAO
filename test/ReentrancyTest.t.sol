// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "src/contracts/interfaces/ISimpleDAO.sol";
import "src/contracts/SimpleDAO.sol";
import "./AttackerContract.sol"; // Підключаємо контракт атаки

contract ReentrancyTest is Test {
    SimpleDAO public dao;
    AttackerContract public attacker;
    address payable owner;
    address payable attackerAddress;
    uint256 private constant ATTACK_AMOUNT = 0.5 ether;

    function setUp() public {
        // Fund test contract
        vm.deal(address(this), 100 ether);

        // Deploy contracts
        dao = new SimpleDAO();
        attacker = new AttackerContract(address(dao));
        
        // Setup addresses
        owner = payable(address(this));
        attackerAddress = payable(address(attacker));

        // Fund DAO with initial balance
        dao.donate{value: 2 ether}();
    }

    function testReentrancyAttack() public {
        // Record initial state
        uint256 initialDAOBalance = address(dao).balance;
        uint256 initialAttackerBalance = address(attacker).balance;
        uint256 initialOwnerBalance = address(owner).balance;

        console.log("Initial DAO balance:", initialDAOBalance);
        console.log("Initial Attacker contract balance:", initialAttackerBalance);
        console.log("Initial Owner balance:", initialOwnerBalance);

        // Perform the attack
        attacker.attack{value: ATTACK_AMOUNT}();

        // Record final state
        uint256 finalDAOBalance = address(dao).balance;
        uint256 finalAttackerBalance = address(attacker).balance;
        uint256 finalOwnerBalance = address(owner).balance;

        console.log("Final DAO balance:", finalDAOBalance);
        console.log("Final Attacker contract balance:", finalAttackerBalance);
        console.log("Final Owner balance:", finalOwnerBalance);

        // Verify attack success
        assertLt(finalDAOBalance, initialDAOBalance, "DAO balance should decrease");
        assertGt(finalOwnerBalance, initialOwnerBalance, "Owner should profit from attack");
    }

    receive() external payable {}
}
