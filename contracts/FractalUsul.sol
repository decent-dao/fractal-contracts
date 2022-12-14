//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Usul was previously named "Seele" and SekerDAO was TokenWalk
// that's where this naming differences are coming from
import "@tokenwalk/seele/contracts/Usul.sol";

contract FractalUsul is Usul {
  struct Transaction {
    address to;
    uint256 value;
    bytes data;
    Enum.Operation operation;
  }

  event ProposalMetadataCreated(
    uint256 proposalId, 
    Transaction[] transactions,
    string title,
    string description, 
    string documentationUrl
  );

  constructor(
    address _owner,
    address _avatar,
    address _target,
    address[] memory _strategies
  ) Usul(_owner, _avatar, _target, _strategies) {}

  /// @dev This method is used instead of Usul.submitProposal. Essentially - it just implements same behavior
  /// but then - it also emits metadata of the proposal in ProposalMetadataCreated event.
  /// @param strategy Address of Voting Strategy, under which proposal submitted
  /// @param data - any additional data, which would be passed into IStrategy.receiveProposal
  /// @param transactions - array of transactions to execute
  /// @param title - proposal title, emitted in ProposalMetadataCreated
  /// @param description - proposal description, emitted in ProposalMetadataCreated
  /// @param documentationUrl - proposal documentation/discussion URL, emitted in ProposalMetadataCreated. 
  /// Supposed to be link to Discord/Slack/Whatever chat discussion
  function submitProposalWithMetaData(
        address strategy,
        bytes memory data,
        Transaction[] calldata transactions,
        string calldata title,
        string calldata description,
        string calldata documentationUrl
  ) external {
      require(
          isStrategyEnabled(strategy),
          "voting strategy is not enabled for proposal"
      );
      require(transactions.length > 0, "proposal must contain transactions");

      bytes32[] memory txHashes = new bytes32[](transactions.length);
      for (uint256 i = 0; i < transactions.length; i++) {
        txHashes[i] = getTransactionHash(
          transactions[i].to, 
          transactions[i].value,
          transactions[i].data, 
          transactions[i].operation
        );
      }

      proposals[totalProposalCount].txHashes = txHashes;
      proposals[totalProposalCount].strategy = strategy;
      IStrategy(strategy).receiveProposal(
          abi.encode(totalProposalCount, txHashes, data)
      );
      emit ProposalCreated(strategy, totalProposalCount, msg.sender);
      emit ProposalMetadataCreated(
        totalProposalCount, 
        transactions, 
        title, 
        description, 
        documentationUrl
      );
      totalProposalCount++;
  }

  /// @notice Gets the transaction hashes associated with a given proposald
  /// @param proposalId The ID of the proposal to get the tx hashes for
  /// @return bytes32[] The array of tx hashes
  function getProposalTxHashes(uint256 proposalId) external view returns (bytes32[] memory) {
    return proposals[proposalId].txHashes;
  }
}