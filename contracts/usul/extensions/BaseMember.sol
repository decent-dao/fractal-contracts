// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity ^0.8.0;

import "../BaseStrategy.sol";

/// @title Base Membership - A Usul strategy extension that enables membership gates.
/// @author Nathan Ginnever - <team@hyphal.xyz>
abstract contract BaseMember is BaseStrategy {
    uint256 public memberCount;

    mapping(address => bool) public members;

    modifier onlyMember(address voter) {
        require(members[voter], "voter is not a member");
        _;
    }

    event MemberAdded(address member);
    event MemberRemoved(address member);

    function addMember(address member) public virtual onlyOwner {
        require(members[member] == false, "member is already registered");
        members[member] = true;
        memberCount++;
        emit MemberAdded(member);
    }

    function removeMember(address member) public virtual onlyOwner {
        require(members[member] == true, "member is not registered");
        members[member] = false;
        memberCount--;
        emit MemberRemoved(member);
    }
}
