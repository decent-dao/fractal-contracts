//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IVetoGuard.sol";
import "./interfaces/IVetoVoting.sol";
import "./interfaces/IGnosisSafe.sol";
import "./TransactionHasher.sol";
import "./FractalBaseGuard.sol";
import "@gnosis.pm/zodiac/contracts/factory/FactoryFriendly.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";

/// @notice A guard contract that prevents transactions that have been vetoed from being executed on the Gnosis Safe
contract VetoGuard is
    TransactionHasher,
    FactoryFriendly,
    FractalBaseGuard,
    IVetoGuard
{
    uint256 public timelockPeriod;
    uint256 public executionPeriod;
    IVetoVoting public vetoVoting;
    IGnosisSafe public gnosisSafe;
    mapping(bytes32 => uint256) internal transactionQueuedBlock;
    mapping(bytes32 => uint256) internal transactionQueuedTimestamp;

    /// @notice Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (
            uint256 _timelockPeriod,
            uint256 _executionPeriod,
            address _owner,
            address _vetoVoting,
            address _gnosisSafe // Address(0) == msg.sender
        ) = abi.decode(
                initializeParams,
                (uint256, uint256, address, address, address)
            );

        timelockPeriod = _timelockPeriod;
        executionPeriod = _executionPeriod;
        transferOwnership(_owner);
        vetoVoting = IVetoVoting(_vetoVoting);
        gnosisSafe = IGnosisSafe(
            _gnosisSafe == address(0) ? msg.sender : _gnosisSafe
        );

        emit VetoGuardSetup(
            msg.sender,
            _timelockPeriod,
            _executionPeriod,
            _owner,
            _vetoVoting
        );
    }

    /// @notice Allows a user to queue the transaction, requires valid signatures
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @param operation Operation type.
    /// @param safeTxGas Gas that should be used for the safe transaction.
    /// @param baseGas Gas costs for that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
    /// @param gasPrice Maximum gas price that should be used for this transaction.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
    /// @param signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
    function queueTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external {
        bytes32 transactionHash = getTransactionHash(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver
        );

        require(
            block.timestamp >=
                transactionQueuedTimestamp[transactionHash] +
                    timelockPeriod +
                    executionPeriod,
            "Transaction has already been queued recently"
        );

        bytes memory gnosisTransactionHash = gnosisSafe.encodeTransactionData(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            gnosisSafe.nonce()
        );

        // If signatures are not valid, this will revert
        gnosisSafe.checkSignatures(
            keccak256(gnosisTransactionHash),
            gnosisTransactionHash,
            signatures
        );

        transactionQueuedBlock[transactionHash] = block.number;
        transactionQueuedTimestamp[transactionHash] = block.timestamp;

        emit TransactionQueued(msg.sender, transactionHash, signatures);
    }

    /// @notice Updates the timelock period in seconds, only callable by the owner
    /// @param _timelockPeriod The number of seconds between when a transaction is queued and can be executed
    function updateTimelockPeriod(uint256 _timelockPeriod) external onlyOwner {
        timelockPeriod = _timelockPeriod;
    }

    /// @notice Updates the execution period in seconds, only callable by the owner
    /// @param _executionPeriod The number of seconds a transaction has to be executed after timelock period has ended
    function updateExecutionPeriod(uint256 _executionPeriod)
        external
        onlyOwner
    {
        executionPeriod = _executionPeriod;
    }

    /// @notice This function is called by the Gnosis Safe to check if the transaction should be able to be executed
    /// @notice Reverts if this transaction cannot be executed
    /// @param to Destination address.
    /// @param value Ether value.
    /// @param data Data payload.
    /// @param operation Operation type.
    /// @param safeTxGas Gas that should be used for the safe transaction.
    /// @param baseGas Gas costs for that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
    /// @param gasPrice Maximum gas price that should be used for this transaction.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory,
        address
    ) external view override {
        bytes32 transactionHash = getTransactionHash(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver
        );

        require(
            transactionQueuedBlock[transactionHash] != 0,
            "Transaction has not been queued yet"
        );

        require(
            block.timestamp >=
                transactionQueuedTimestamp[transactionHash] + timelockPeriod,
            "Transaction timelock period has not completed yet"
        );

        require(
            block.timestamp <=
                transactionQueuedTimestamp[transactionHash] +
                    timelockPeriod +
                    executionPeriod,
            "Transaction execution period has ended"
        );

        require(
            !vetoVoting.getIsVetoed(transactionHash),
            "Transaction has been vetoed"
        );

        require(!vetoVoting.isFrozen(), "DAO is frozen");
    }

    /// @notice Does checks after transaction is executed on the Gnosis Safe
    /// @param txHash The hash of the transaction that was executed
    /// @param success Boolean indicating whether the Gnosis Safe successfully executed the tx
    function checkAfterExecution(bytes32 txHash, bool success)
        external
        view
        override
    {}

    /// @notice Gets the block number that the transaction was queued at
    /// @param _transactionHash The hash of the transaction data
    /// @return uint256 The block number
    function getTransactionQueuedBlock(bytes32 _transactionHash)
        public
        view
        returns (uint256)
    {
        return transactionQueuedBlock[_transactionHash];
    }

    /// @notice Gets the timestamp that the transaction was queued at
    /// @param _transactionHash The hash of the transaction data
    /// @return uint256 The timestamp the transaction was queued at
    function getTransactionQueuedTimestamp(bytes32 _transactionHash)
        public
        view
        returns (uint256)
    {
        return transactionQueuedTimestamp[_transactionHash];
    }

    /// @notice Can be used to check if this contract supports the specified interface
    /// @param interfaceId The bytes representing the interfaceId being checked
    /// @return bool True if this contract supports the checked interface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(FractalBaseGuard)
        returns (bool)
    {
        return
            interfaceId == type(IVetoGuard).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
