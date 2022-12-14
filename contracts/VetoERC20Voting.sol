//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVetoGuard.sol";
import "./interfaces/IVetoVoting.sol";
import "./TransactionHasher.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@gnosis.pm/zodiac/contracts/factory/FactoryFriendly.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @notice A contract for casting veto votes with an ERC20 votes token
contract VetoERC20Voting is IVetoVoting, TransactionHasher, FactoryFriendly {
    uint256 public vetoVotesThreshold; // Number of votes required to veto a transaction
    uint256 public freezeVotesThreshold; // Number of freeze votes required to activate a freeze
    uint256 public freezeProposalCreatedBlock; // Block number the freeze proposal was created at
    uint256 public freezeProposalCreatedTime; // Timestsamp the freeze proposal was created at  
    uint256 public freezeProposalVoteCount; // Number of accrued freeze votes
    uint256 public freezeProposalPeriod; // Number of seconds a freeze proposal has to succeed
    uint256 public freezePeriod; // Number of seconds a freeze lasts, from time of freeze proposal creation
    IVotes public votesToken;
    IVetoGuard public vetoGuard;
    mapping(bytes32 => uint256) public transactionVetoVotes;
    mapping(address => mapping(bytes32 => bool)) public userHasVoted;
    mapping(address => mapping(uint256 => bool)) public userHasFreezeVoted;

    /// @notice Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (
            address _owner,
            uint256 _vetoVotesThreshold,
            uint256 _freezeVotesThreshold,
            uint256 _freezeProposalPeriod,
            uint256 _freezePeriod,
            address _votesToken,
            address _vetoGuard
        ) = abi.decode(
                initializeParams,
                (address, uint256, uint256, uint256, uint256, address, address)
            );

        _transferOwnership(_owner);
        vetoVotesThreshold = _vetoVotesThreshold;
        freezeVotesThreshold = _freezeVotesThreshold;
        freezeProposalPeriod = _freezeProposalPeriod;
        freezePeriod = _freezePeriod;
        votesToken = IVotes(_votesToken);
        vetoGuard = IVetoGuard(_vetoGuard);
    }

    /// @notice Allows the msg.sender to cast veto and freeze votes on the specified transaction
    /// @param _transactionHash The hash of the transaction data
    /// @param _freeze Bool indicating whether the voter thinks the DAO should also be frozen
    function castVetoVote(bytes32 _transactionHash, bool _freeze) external {
        // Check that user has not yet voted
        require(
            !userHasVoted[msg.sender][_transactionHash],
            "User has already voted"
        );

        // Get the block number the transaction was queued on the VetoGuard
        uint256 queuedBlockNumber = vetoGuard.getTransactionQueuedBlock(
            _transactionHash
        );

        // Check that the transaction has been queued
        require(queuedBlockNumber != 0, "Transaction has not yet been queued");

        uint256 vetoVotes = votesToken.getPastVotes(
            msg.sender,
            queuedBlockNumber - 1
        );

        require(vetoVotes > 0, "User has no votes");

        // Add the user votes to the veto vote count for this transaction
        transactionVetoVotes[_transactionHash] += vetoVotes;

        // If the user is voting to freeze, count that vote as well
        if (_freeze) {
            castFreezeVote();
        }

        // User has voted
        userHasVoted[msg.sender][_transactionHash] = true;

        emit VetoVoteCast(msg.sender, _transactionHash, vetoVotes, _freeze);
    }

    /// @notice Allows user to cast a freeze vote, creating a freeze proposal if necessary
    function castFreezeVote() public {
        uint256 userVotes;

        if (
            block.timestamp >
            freezeProposalCreatedTime + freezeProposalPeriod
        ) {
            // Create freeze proposal, set total votes to msg.sender's vote count
            freezeProposalCreatedBlock = block.number;
            freezeProposalCreatedTime = block.timestamp;

            userVotes = votesToken.getPastVotes(
                msg.sender,
                freezeProposalCreatedBlock - 1
            );
            require(userVotes > 0, "User has no votes");

            freezeProposalVoteCount = userVotes;

            emit FreezeProposalCreated(msg.sender);
        } else {
            // There is an existing freeze proposal, count user's votes
            require(
                !userHasFreezeVoted[msg.sender][freezeProposalCreatedBlock],
                "User has already voted"
            );

            userVotes = votesToken.getPastVotes(
                msg.sender,
                freezeProposalCreatedBlock - 1
            );
            require(userVotes > 0, "User has no votes");

            freezeProposalVoteCount += userVotes;
        }

        userHasFreezeVoted[msg.sender][freezeProposalCreatedBlock] = true;

        emit FreezeVoteCast(msg.sender, userVotes);
    }

    /// @notice Unfreezes the DAO, only callable by the owner
    function defrost() public onlyOwner {
        freezeProposalCreatedBlock = 0;
        freezeProposalCreatedTime = 0;
        freezeProposalVoteCount = 0;
    }

    /// @notice Updates the veto votes threshold, only callable by the owner
    /// @param _vetoVotesThreshold The number of votes required to veto a transaction
    function updateVetoVotesThreshold(uint256 _vetoVotesThreshold)
        external
        onlyOwner
    {
        vetoVotesThreshold = _vetoVotesThreshold;
    }

    /// @notice Updates the freeze votes threshold, only callable by the owner
    /// @param _freezeVotesThreshold Number of freeze votes required to activate a freeze
    function updateFreezeVotesThreshold(uint256 _freezeVotesThreshold)
        external
        onlyOwner
    {
        freezeVotesThreshold = _freezeVotesThreshold;
    }

    /// @notice Updates the freeze proposal period, only callable by the owner
    /// @param _freezeProposalPeriod The number of seconds a freeze proposal has to succeed
    function updateFreezeProposalPeriod(
        uint256 _freezeProposalPeriod
    ) external onlyOwner {
        freezeProposalPeriod = _freezeProposalPeriod;
    }

    /// @notice Updates the freeze period, only callable by the owner
    /// @param _freezePeriod The number of seconds a freeze lasts, from time of freeze proposal creation
    function updateFreezePeriod(uint256 _freezePeriod)
        external
        onlyOwner
    {
        freezePeriod = _freezePeriod;
    }

    /// @notice Returns whether the specified transaction has been vetoed
    /// @param _transactionHash The hash of the transaction data
    /// @return bool True if the transaction is vetoed
    function getIsVetoed(bytes32 _transactionHash)
        external
        view
        returns (bool)
    {
        return transactionVetoVotes[_transactionHash] > vetoVotesThreshold;
    }

    /// @notice Returns true if the DAO is currently frozen, false otherwise
    /// @return bool Indicates whether the DAO is currently frozen
    function isFrozen() external view returns (bool) {
        if (
            freezeProposalVoteCount > freezeVotesThreshold &&
            block.timestamp < freezeProposalCreatedTime + freezePeriod
        ) {
            return true;
        }

        return false;
    }
}
