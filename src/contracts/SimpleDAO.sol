// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/ISimpleDAO.sol";

/**
 * @title SimpleDAO
 * @dev A simplified DAO contract with intentional vulnerabilities for security research
 */
contract SimpleDAO is ISimpleDAO {
    mapping(address => uint256) public balances;

    struct Proposal {
        address payable recipient;
        uint256 amount;
        string description;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
    }

    Proposal[] public proposals;

    // Events
    event Donated(address indexed donor, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address recipient, uint256 amount);
    event Voted(uint256 indexed proposalId, address voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    // Vulnerable donate function - no checks on amount
    function donate() public payable {
        balances[msg.sender] += msg.value;
        emit Donated(msg.sender, msg.value);
    }

    // Vulnerable withdraw function - susceptible to reentrancy
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount);

        // Vulnerability: State change after external call
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] -= amount;

        emit Withdrawn(msg.sender, amount);
    }

    // Vulnerable proposal creation - no minimum balance requirement
    function createProposal(address payable recipient, uint256 amount, string memory description)
        public
        returns (uint256)
    {
        // Vulnerability: No minimum balance check
        uint256 proposalId = proposals.length;
        Proposal storage newProposal = proposals.push();
        newProposal.recipient = recipient;
        newProposal.amount = amount;
        newProposal.description = description;
        newProposal.executed = false;
        newProposal.votesFor = 0;
        newProposal.votesAgainst = 0;

        emit ProposalCreated(proposalId, recipient, amount);
        return proposalId;
    }

    // Vulnerable voting system - no checks for voting weight
    function vote(uint256 proposalId, bool support) public {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted");

        if (support) {
            proposal.votesFor += 1;
        } else {
            proposal.votesAgainst += 1;
        }

        proposal.hasVoted[msg.sender] = true;
        emit Voted(proposalId, msg.sender, support);
    }

    // Vulnerable execute function - no access control
    function executeProposal(uint256 proposalId) public {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");

        // Vulnerability: No quorum check, no timelock, no access control
        proposal.executed = true;
        (bool success,) = proposal.recipient.call{value: proposal.amount}("");
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    receive() external payable {
        donate();
    }
}
