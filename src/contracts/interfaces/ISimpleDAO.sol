// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISimpleDAO {
    function donate() external payable;
    function withdraw(uint256 amount) external;
    function createProposal(address payable recipient, uint256 amount, string memory description)
        external
        returns (uint256);
    function vote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function balances(address account) external view returns (uint256);
}
