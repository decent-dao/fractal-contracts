//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IOZLinearVoting {
    /// @dev Calls the proposal module to notify that a quorum has been reached.
    /// @param proposalId the proposal to vote for.
    function finalizeStrategy(uint256 proposalId) external;

    /// @dev Determines if a proposal has succeeded.
    /// @param proposalId the proposal to vote for.
    /// @return boolean.
    function isPassed(uint256 proposalId) external view returns (bool);

    function proposals(uint256 proposalId) external view returns (
      uint256 yesVotes, uint256 noVotes, uint256 abstainVotes, uint256 deadline, uint256 startBlock
    );
}