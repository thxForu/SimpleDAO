// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract SecureSimpleDAO is ReentrancyGuard, AccessControl, Pausable {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    mapping(address => uint256) private _balances;
    uint256 private constant MINIMUM_PROPOSAL_BALANCE = 1 ether;
    uint256 private constant PROPOSAL_VOTING_PERIOD = 7 days;
    uint256 private constant EXECUTION_DELAY = 2 days;

    struct Proposal {
        address payable recipient;
        uint256 amount;
        string description;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 executionTime;
        mapping(address => bool) hasVoted;
    }

    Proposal[] private _proposals;

    event Donated(address indexed donor, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);
    event ProposalCreated(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 executionTime);

    constructor() {
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(EXECUTOR_ROLE, msg.sender);
    }

    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId < _proposals.length, "Invalid proposal ID");
        _;
    }

    /**
     * @dev Safely donate funds to the DAO
     * @notice Uses checks-effects-interactions pattern
     */
    function donate() public payable whenNotPaused {
        require(msg.value > 0, "Must send positive value");

        uint256 newBalance = _balances[msg.sender] + msg.value;
        _balances[msg.sender] = newBalance;

        emit Donated(msg.sender, msg.value, newBalance);
    }

    /**
     * @dev Safely withdraw funds from the DAO
     * @notice Implements reentrancy protection
     */
    function withdraw(uint256 amount) public nonReentrant whenNotPaused {
        require(amount > 0, "Must withdraw positive amount");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        // Update state before external call
        _balances[msg.sender] -= amount;

        // Safe external call with appropriate error handling
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount, _balances[msg.sender]);
    }

    /**
     * @dev Create a new proposal with proper validation
     */
    function createProposal(address payable recipient, uint256 amount, string memory description)
        public
        whenNotPaused
        returns (uint256)
    {
        require(_balances[msg.sender] >= MINIMUM_PROPOSAL_BALANCE, "Insufficient balance to create proposal");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0 && amount <= address(this).balance, "Invalid amount");
        require(bytes(description).length > 0, "Description required");

        uint256 proposalId = _proposals.length;
        Proposal storage newProposal = _proposals.push();

        newProposal.recipient = recipient;
        newProposal.amount = amount;
        newProposal.description = description;
        newProposal.createdAt = block.timestamp;

        emit ProposalCreated(proposalId, recipient, amount);
        return proposalId;
    }

    /**
     * @dev Vote on a proposal with proper validation and state management
     */
    function vote(uint256 proposalId, bool support) public onlyValidProposal(proposalId) whenNotPaused {
        Proposal storage proposal = _proposals[proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp < proposal.createdAt + PROPOSAL_VOTING_PERIOD, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(_balances[msg.sender] > 0, "Must have balance to vote");

        if (support) {
            proposal.votesFor += _balances[msg.sender];
        } else {
            proposal.votesAgainst += _balances[msg.sender];
        }

        proposal.hasVoted[msg.sender] = true;
        emit Voted(proposalId, msg.sender, support);
    }

    /**
     * @dev Queue proposal for execution after voting period
     */
    function queueProposal(uint256 proposalId) public onlyValidProposal(proposalId) whenNotPaused {
        Proposal storage proposal = _proposals[proposalId];

        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.createdAt + PROPOSAL_VOTING_PERIOD, "Voting still active");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal failed");

        proposal.executionTime = block.timestamp + EXECUTION_DELAY;
        emit ProposalQueued(proposalId, proposal.executionTime);
    }

    /**
     * @dev Execute a passed proposal with proper access control and validation
     */
    function executeProposal(uint256 proposalId)
        public
        onlyRole(EXECUTOR_ROLE)
        onlyValidProposal(proposalId)
        nonReentrant
        whenNotPaused
    {
        Proposal storage proposal = _proposals[proposalId];

        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal failed");
        require(address(this).balance >= proposal.amount, "Insufficient contract balance");

        proposal.executed = true;

        (bool success,) = proposal.recipient.call{value: proposal.amount}("");
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Emergency pause functionality
     */
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev View functions for getting contract state
     */
    function getBalance(address account) public view returns (uint256) {
        return _balances[account];
    }

    function getProposalCount() public view returns (uint256) {
        return _proposals.length;
    }

    receive() external payable {
        donate();
    }

    fallback() external payable {
        revert("Function not found");
    }
}
