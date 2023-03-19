//SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "./interfaces/IERC20Claim.sol";
import "./VotesERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Claim is FactoryFriendly, IERC20Claim {
    using SafeERC20 for IERC20;

    address public funder;
    uint256 public deadlineBlock;
    address public childERC20;
    address public parentERC20;
    uint256 public snapShotId;
    uint256 public parentAllocation;
    mapping(address => bool) public claimed;

    event ERC20Claimed(
        address indexed pToken,
        address indexed cToken,
        address indexed claimer,
        uint256 amount
    );

    error NoAllocation();
    error AllocationClaimed();
    error NotTheFunder();
    error NoDeadline();
    error DeadlinePending();
    
    event ERC20ClaimCreated(
        address parentToken,
        address childToken,
        uint256 parentAllocation,
        uint256 snapshotId,
        uint256 deadline
    );

    /// @notice Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (
            address _childTokenFunder,
            uint256 _deadlineBlock,
            address _parentERC20,
            address _childERC20,
            uint256 _parentAllocation
        ) = abi.decode(initializeParams, (address, uint256, address, address, uint256));

        funder = _childTokenFunder;
        deadlineBlock = _deadlineBlock;
        childERC20 = _childERC20;
        parentERC20 = _parentERC20;
        parentAllocation = _parentAllocation;

        snapShotId = VotesERC20(_parentERC20).captureSnapShot();

        IERC20(_childERC20).safeTransferFrom(
            _childTokenFunder,
            address(this),
            _parentAllocation
        );

        emit ERC20ClaimCreated(
            _parentERC20,
            _childERC20,
            _parentAllocation,
            snapShotId,
            _deadlineBlock
        );
    }

    /// @notice This function allows pToken holders to claim cTokens
    /// @param claimer Address which is being claimed for
    function claimToken(address claimer) external {
        uint256 amount = getClaimAmount(claimer); // Get user balance

        if (amount == 0) revert NoAllocation();

        claimed[claimer] = true;

        IERC20(childERC20).safeTransfer(claimer, amount); // transfer user balance

        emit ERC20Claimed(parentERC20, childERC20, claimer, amount);
    }

    /// @notice Gets a users child token claimable amount
    /// @param claimer Address which is being claimed for
    /// @return cTokenAllocation Users cToken allocation
    function getClaimAmount(address claimer) public view returns (uint256) {
        return
            claimed[claimer]
                ? 0
                : (VotesERC20(parentERC20).balanceOfAt(claimer, snapShotId) *
                    parentAllocation) /
                    VotesERC20(parentERC20).totalSupplyAt(snapShotId);
    }

    /// @notice Returns unclaimed tokens after the deadline to the funder.
    function reclaim() external {
        if (msg.sender != funder) revert NotTheFunder();
        if (deadlineBlock == 0) revert NoDeadline();
        if (block.number < deadlineBlock) revert DeadlinePending();
        IERC20 token = IERC20(childERC20);
        token.safeTransfer(funder, token.balanceOf(address(this)));
    }
}