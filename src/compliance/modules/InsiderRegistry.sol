// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../../interfaces/IInsiderRegistry.sol";
import "../../roles/AgentRoleUpgradeable.sol";
import "../../storage/InsiderStorage.sol";

/**
 * @title InsiderRegistry
 * @dev Contract for tracking wallet addresses that are considered "insiders" for 
 * regulatory compliance purposes. Insiders may have different trading restrictions
 * or exemptions from standard compliance rules.
 */
contract InsiderRegistry is 
    IInsiderRegistry, 
    Initializable, 
    OwnableUpgradeable, 
    UUPSUpgradeable, 
    AgentRoleUpgradeable
{
    using InsiderStorage for InsiderStorage.Layout;
    
    /**
     * @dev Initializes the contract with the deployer as AGENT
     */
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        // Add deployer as an AGENT insider
        _addInsider(msg.sender, uint8(InsiderType.AGENT));
        
        // Add deployer as an agent
        addAgent(msg.sender);
    }
    
    /**
     * @dev Adds a wallet as an insider with a specified type
     * @param _wallet The address to register as an insider
     * @param _insiderType The type of insider (from InsiderType enum)
     */
    function addInsider(address _wallet, uint8 _insiderType) external override onlyOwnerOrAgent {
        _addInsider(_wallet, _insiderType);
    }
    
    /**
     * @dev Internal function to add an insider
     * @param _wallet The address to register as an insider
     * @param _insiderType The type of insider (from InsiderType enum)
     */
    function _addInsider(address _wallet, uint8 _insiderType) internal {
        require(_wallet != address(0), "InsiderRegistry: invalid address");
        require(_insiderType > 0 && _insiderType <= uint8(InsiderType.AGENT), "InsiderRegistry: invalid insider type");
        require(!InsiderStorage.layout().isInsider(_wallet), "InsiderRegistry: address already registered");
        
        // Add to storage
        InsiderStorage.layout().addInsider(_wallet, _insiderType);
        
        emit InsiderAdded(_wallet, _insiderType);
    }
    
    /**
     * @dev Removes a wallet from the insider list
     * @param _wallet The address to remove from the insider registry
     */
    function removeInsider(address _wallet) external override onlyOwnerOrAgent {
        require(_wallet != address(0), "InsiderRegistry: invalid address");
        require(InsiderStorage.layout().isInsider(_wallet), "InsiderRegistry: address not registered");
        
        // Remove from storage
        InsiderStorage.layout().removeInsider(_wallet);
        
        emit InsiderRemoved(_wallet);
    }
    
    /**
     * @dev Updates the insider type for an existing insider
     * @param _wallet The address of the insider
     * @param _newType The new insider type to assign
     */
    function updateInsiderType(address _wallet, uint8 _newType) external override onlyOwnerOrAgent {
        require(_wallet != address(0), "InsiderRegistry: invalid address");
        require(InsiderStorage.layout().isInsider(_wallet), "InsiderRegistry: address not registered");
        require(_newType > 0 && _newType <= uint8(InsiderType.AGENT), "InsiderRegistry: invalid insider type");
        
        // Update type in storage
        InsiderStorage.layout().updateInsiderType(_wallet, _newType);
        
        emit InsiderTypeUpdated(_wallet, _newType);
    }
    
    /**
     * @dev Checks if a wallet is registered as an insider
     * @param _wallet The address to check
     * @return bool True if the wallet is an insider
     */
    function isInsider(address _wallet) external view override returns (bool) {
        return InsiderStorage.layout().isInsider(_wallet);
    }
    
    /**
     * @dev Gets the insider type for a wallet
     * @param _wallet The address to check
     * @return uint8 The insider type (from InsiderType enum)
     */
    function getInsiderType(address _wallet) external view override returns (uint8) {
        return InsiderStorage.layout().getInsiderType(_wallet);
    }
    
    /**
     * @dev Gets the list of all insiders
     * @return address[] Array of insider addresses
     */
    function getInsiders() external view override returns (address[] memory) {
        return InsiderStorage.layout().getInsiders();
    }
    
    /**
     * @dev Gets the list of insiders of a specific type
     * @param _type The insider type to filter by
     * @return address[] Array of insider addresses of the specified type
     */
    function getInsidersByType(uint8 _type) external view override returns (address[] memory) {
        require(_type > 0 && _type <= uint8(InsiderType.AGENT), "InsiderRegistry: invalid insider type");
        return InsiderStorage.layout().getInsidersByType(_type);
    }
    
    /**
     * @dev Combined modifier for owner or agent
     */
    modifier onlyOwnerOrAgent() {
        require(owner() == msg.sender || isAgent(msg.sender), "InsiderRegistry: caller is not owner or agent");
        _;
    }
    
    /**
     * @dev Required by UUPSUpgradeable
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}