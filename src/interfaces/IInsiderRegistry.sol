// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/**
 * @title IInsiderRegistry
 * @dev Interface for the InsiderRegistry contract which tracks addresses that are
 * considered "insiders" for regulatory compliance purposes.
 */
interface IInsiderRegistry {
    /**
     * @dev Insider type enum values
     */
    enum InsiderType {
        NONE,       // 0: Not an insider
        FOUNDER,    // 1: Founder
        EXECUTIVE,  // 2: Executive
        DIRECTOR,   // 3: Director
        EMPLOYEE,   // 4: Employee
        AGENT       // 5: Agent
    }

    /**
     * @dev Adds a wallet as an insider with a specific type
     * @param _wallet The address to register as an insider
     * @param _insiderType The type of insider (from InsiderType enum)
     */
    function addInsider(address _wallet, uint8 _insiderType) external;
    
    /**
     * @dev Removes a wallet from the insider list
     * @param _wallet The address to remove from the insider registry
     */
    function removeInsider(address _wallet) external;
    
    /**
     * @dev Updates the insider type for an existing insider
     * @param _wallet The address of the insider
     * @param _newType The new insider type to assign
     */
    function updateInsiderType(address _wallet, uint8 _newType) external;
    
    /**
     * @dev Checks if a wallet is registered as an insider
     * @param _wallet The address to check
     * @return bool True if the wallet is an insider
     */
    function isInsider(address _wallet) external view returns (bool);
    
    /**
     * @dev Gets the insider type for a wallet
     * @param _wallet The address to check
     * @return uint8 The insider type (from InsiderType enum)
     */
    function getInsiderType(address _wallet) external view returns (uint8);
    
    /**
     * @dev Gets the list of all insiders
     * @return address[] Array of insider addresses
     */
    function getInsiders() external view returns (address[] memory);
    
    /**
     * @dev Gets the list of insiders of a specific type
     * @param _type The insider type to filter by
     * @return address[] Array of insider addresses of the specified type
     */
    function getInsidersByType(uint8 _type) external view returns (address[] memory);

    /**
     * @dev Emitted when a new insider is added to the registry
     */
    event InsiderAdded(address indexed wallet, uint8 insiderType);
    
    /**
     * @dev Emitted when an insider is removed from the registry
     */
    event InsiderRemoved(address indexed wallet);
    
    /**
     * @dev Emitted when an insider's type is updated
     */
    event InsiderTypeUpdated(address indexed wallet, uint8 newType);
}