// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Fix import paths
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title SecurityTokenImplementation
/// @notice Base contract for security token implementations to ensure UUPS compatibility
abstract contract SecurityTokenImplementation is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice Version identifier
    string public implVersion;
    
    /// @notice Component type identifier
    string public componentType;

    /// @dev Set version and component type during initialization
    function __SecurityTokenImplementation_init(string memory _version, string memory _componentType) internal onlyInitializing {
        __Ownable_init(msg.sender); // Pass msg.sender as the initial owner
        __UUPSUpgradeable_init();
        implVersion = _version;
        componentType = _componentType;
    }

    /// @dev Override authorization to upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    /// @notice Get version of the implementation
    function getImplVersion() external view returns (string memory) {
        return implVersion;
    }
    
    /// @notice Get component type of the implementation
    function getComponentType() external view returns (string memory) {
        return componentType;
    }
}