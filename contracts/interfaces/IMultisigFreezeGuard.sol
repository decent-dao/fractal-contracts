//SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

/**
 * A specification for a Safe Guard contract which allows for multi-sig DAOs (Safes)
 * to operate in a fashion similar to Azorius token voting DAOs.
 *
 * This Guard is intended to add a timelock period and execution period to a Safe
 * multisig contract, allowing parent DAO's to have the ability to properly
 * freeze multi-sig subDAOs.
 *
 * Without a timelock period, a vote to freeze the Safe would not be possible
 * as the multi-sig child could immediately execute any transactions they would like
 * in response.
 *
 * An execution period is also required // TODO we had a reason to require this, what was that
 *
 * See also https://docs.safe.global/learn/safe-core/safe-core-protocol/guards
 */
interface IMultisigFreezeGuard { // TODO FreezeGuard name feels off here, as it's not exactly freezing anything, just adding parameters to a multisig

    /**
     * Allows the caller to begin the "timelock" of a transaction.
     *
     * Timelock is the period during which a proposed transaction must wait before being
     * executed, after it has passed.  This period is intended to allow the parent DAO
     * sufficient time to potentially freeze the DAO, if they should vote to do so.
     *
     * The parameters for doing so are identical to IGnosisSafe's execTransaction function.
     *
     * @param _to destination address
     * @param _value ETH value
     * @param _data data payload
     * @param _operation Operation type, Call or DelegateCall
     * @param _safeTxGas gas that should be used for the safe transaction
     * @param _baseGas gas costs that are independent of the transaction execution
     * @param _gasPrice max gas price that should be used for this transaction // TODO isn't there a different way to structure transactions now?
     * @param _gasToken token address (or 0 if ETH) that is used for the payment // TODO what's this paying with other tokens about?
     * @param _refundReceiver address of the receiver of gas payment (or 0 if tx.origin)
     * @param _signatures packed signature data
     */
    function timelockTransaction(
        address _to,
        uint256 _value,
        bytes memory _data,
        Enum.Operation _operation,
        uint256 _safeTxGas,
        uint256 _baseGas,
        uint256 _gasPrice,
        address _gasToken,
        address payable _refundReceiver,
        bytes memory _signatures
    ) external;

    /**
     * Sets the subDAO's timelock period.
     *
     * @param _timelockPeriod new timelock period for the subDAO (in blocks)
     */
    function updateTimelockPeriod(uint256 _timelockPeriod) external; // TODO change "update" to "set" (also applies to Azorius functions like Voting.sol)

    /**
     * Updates the execution period.
     *
     * Execution period is the time period during which a subDAO's passed Proposals must be executed,
     * otherwise they will be expired.
     *
     * This period begins immediately after the timelock period has ended.
     *
     * @param _executionPeriod number of blocks a transaction has to be executed within
     */
    function updateExecutionPeriod(uint256 _executionPeriod) external;

    /**
     * Gets the block number that the given transaction was timelocked at.
     *
     * @param _transactionHash hash of the transaction data
     * @return uint256 block number in which the transaction began its timelock period
     */
    function getTransactionTimelockedBlock(bytes32 _transactionHash) external view returns (uint256);
}
