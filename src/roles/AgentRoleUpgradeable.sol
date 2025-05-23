// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Roles.sol";

contract AgentRoleUpgradeable is OwnableUpgradeable {
    using Roles for Roles.Role;

    Roles.Role private _agents;

    event AgentAdded(address indexed _agent);
    event AgentRemoved(address indexed _agent);

    modifier onlyAgent() {
        require(isAgent(msg.sender), "AgentRole: caller does not have the Agent role");
        _;
    }
    
    /**
     * @dev Initializes the contract setting the owner as the initial agent
     */
    function __AgentRole_init() internal onlyInitializing {
        // Owner is automatically an agent
        _agents.add(msg.sender);
        emit AgentAdded(msg.sender);
    }

    function addAgent(address _agent) public onlyOwner {
        require(_agent != address(0), "invalid argument - zero address");
        _agents.add(_agent);
        emit AgentAdded(_agent);
    }

    function removeAgent(address _agent) public onlyOwner {
        require(_agent != address(0), "invalid argument - zero address");
        _agents.remove(_agent);
        emit AgentRemoved(_agent);
    }

    function isAgent(address _agent) public view returns (bool) {
        return _agents.has(_agent);
    }
}