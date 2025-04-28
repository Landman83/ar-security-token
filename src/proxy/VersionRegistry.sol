// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title VersionRegistry
/// @notice Central registry for security token versions and implementations
contract VersionRegistry {
    // Governance controls
    address public governance;
    address public pendingGovernance;

    // Version tracking
    struct Implementation {
        address implementation;
        uint256 timestamp;
        string metadata;
        bool deprecated;
    }

    // Component name => version => implementation details
    mapping(string => mapping(string => Implementation)) public implementations;

    // Events
    event ImplementationRegistered(string indexed component, string indexed version, address implementation);
    event ImplementationDeprecated(string indexed component, string indexed version);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);

    modifier onlyGovernance() {
        require(msg.sender == governance, "Registry: caller is not governance");
        _;
    }

    constructor() {
        governance = msg.sender;
    }

    /// @notice Register a new implementation
    function registerImplementation(
        string calldata component,
        string calldata version,
        address implementation,
        string calldata metadata
    ) external onlyGovernance {
        require(implementation != address(0), "Registry: implementation cannot be zero address");
        require(bytes(component).length > 0, "Registry: component name cannot be empty");
        require(bytes(version).length > 0, "Registry: version cannot be empty");

        implementations[component][version] = Implementation({
            implementation: implementation,
            timestamp: block.timestamp,
            metadata: metadata,
            deprecated: false
        });

        emit ImplementationRegistered(component, version, implementation);
    }

    /// @notice Deprecate an implementation
    function deprecateImplementation(string calldata component, string calldata version)
        external onlyGovernance
    {
        require(implementations[component][version].implementation != address(0),
            "Registry: implementation does not exist");

        implementations[component][version].deprecated = true;

        emit ImplementationDeprecated(component, version);
    }

    /// @notice Get implementation address by component and version
    function getImplementation(string calldata component, string calldata version)
        external view returns (address)
    {
        return implementations[component][version].implementation;
    }

    /// @notice Check if implementation is deprecated
    function isDeprecated(string calldata component, string calldata version)
        external view returns (bool)
    {
        return implementations[component][version].deprecated;
    }

    /// @notice Get implementation details by component and version
    function getImplementationDetails(string calldata component, string calldata version)
        external view returns (Implementation memory)
    {
        return implementations[component][version];
    }

    // Governance transition
    function transferGovernance(address _newGovernance) external onlyGovernance {
        require(_newGovernance != address(0), "Registry: new governance cannot be zero address");
        pendingGovernance = _newGovernance;
    }

    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "Registry: only pending governance");
        emit GovernanceTransferred(governance, pendingGovernance);
        governance = pendingGovernance;
        pendingGovernance = address(0);
    }
}