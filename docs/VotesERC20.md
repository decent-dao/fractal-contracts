# Solidity API

## VotesERC20

An implementation of the Open Zeppelin IVotes voting token standard.

### setUp

```solidity
function setUp(bytes initializeParams) public
```

Initialize function, will be triggered when a new instance is deployed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| initializeParams | bytes | encoded initialization parameters |

### captureSnapShot

```solidity
function captureSnapShot() external returns (uint256 snapId)
```

See ERC20SnapshotUpgradeable._snapshot()

### _mint

```solidity
function _mint(address to, uint256 amount) internal virtual
```

### _burn

```solidity
function _burn(address account, uint256 amount) internal virtual
```

### _beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual
```

### _afterTokenTransfer

```solidity
function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual
```
