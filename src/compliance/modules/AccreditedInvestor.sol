// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./AbstractModuleUpgradeable.sol"; // ERC-3643 base module
import "../../interfaces/IToken.sol"; // T-REX Token interface
import "../../interfaces/IModularCompliance.sol"; // Modular Compliance interface
import "../../interfaces/IInsiderRegistry.sol"; // Insider Registry interface
import "st-identity-registry/src/interfaces/IAttributeRegistry.sol"; // Attribute Registry interface
import "st-identity-registry/src/libraries/Attributes.sol"; // Standard attribute types

/**
 * @title AccreditedInvestor Compliance Module
 * @dev Prohibits transfers and mints to wallets that do not have the ACCREDITED_INVESTOR attribute set to true.
 * Allows exemptions for registered insiders when configured.
 */
contract AccreditedInvestor is AbstractModuleUpgradeable {
    // Registry that tracks accredited investor statuses
    IAttributeRegistry public attributeRegistry;
    
    // Registry that tracks insider statuses
    IInsiderRegistry public insiderRegistry;
    
    // Flag to determine if insiders are exempt from accreditation checks
    bool public insidersExemptFromAccreditation;
    
    // Mapping to track initialized status for each compliance
    mapping(address => bool) private _initialized;
    
    // Events
    event AttributeRegistrySet(address indexed oldRegistry, address indexed newRegistry);
    event InsiderRegistrySet(address indexed oldRegistry, address indexed newRegistry);
    event InsiderExemptionSet(bool exemptionStatus);
    event ModuleInitialized(address indexed compliance);
    
    // Modifier to ensure token compliance initialization
    modifier onlyInitialized(address _compliance) {
        require(_initialized[_compliance], "compliance not initialized");
        _;
    }

    // Initialize for upgradeable proxy
    function initialize() external initializer {
        __AbstractModule_init();
    }
    
    // Initialize the module for a specific compliance 
    function initializeModule(address _compliance) external onlyComplianceCall {
        require(!_initialized[_compliance], "module already initialized");
        _initialized[_compliance] = true;
        emit ModuleInitialized(_compliance);
    }
    
    /**
     * @dev Sets the attribute registry contract address
     * @param _attributeRegistry The address of the attribute registry contract
     */
    function setAttributeRegistry(address _attributeRegistry) external onlyOwner {
        require(_attributeRegistry != address(0), "Invalid registry address");
        address oldRegistry = address(attributeRegistry);
        attributeRegistry = IAttributeRegistry(_attributeRegistry);
        emit AttributeRegistrySet(oldRegistry, _attributeRegistry);
    }
    
    /**
     * @dev Sets the insider registry contract address
     * @param _insiderRegistry The address of the insider registry
     */
    function setInsiderRegistry(address _insiderRegistry) external onlyOwner {
        require(_insiderRegistry != address(0), "Invalid registry address");
        address oldRegistry = address(insiderRegistry);
        insiderRegistry = IInsiderRegistry(_insiderRegistry);
        emit InsiderRegistrySet(oldRegistry, _insiderRegistry);
    }
    
    /**
     * @dev Sets whether insiders are exempt from accreditation checks
     * @param _exempt Whether insiders are exempt
     */
    function setInsidersExemptFromAccreditation(bool _exempt) external onlyOwner {
        insidersExemptFromAccreditation = _exempt;
        emit InsiderExemptionSet(_exempt);
    }
    
    /**
     * @dev Checks if an address is an accredited investor or exempt insider
     * @param _address The address to check
     * @return bool True if the address is an accredited investor or exempt insider
     */
    function isAccreditedInvestor(address _address) public view returns (bool) {
        require(address(attributeRegistry) != address(0), "Attribute registry not set");
        
        // Check if address is accredited
        bool isAccredited = attributeRegistry.hasAttribute(_address, Attributes.ACCREDITED_INVESTOR);
        
        // If already accredited, return true
        if (isAccredited) {
            return true;
        }
        
        // If insider exemption is enabled and address is an insider, allow it
        if (insidersExemptFromAccreditation && 
            address(insiderRegistry) != address(0) && 
            insiderRegistry.isInsider(_address)) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Checks if a transfer is compliant
     * @param _from The address of the sender
     * @param _to The address of the receiver
     * @param _value The amount being transferred
     * @param _compliance The address of the compliance contract
     * @return bool True if the transfer is compliant
     */
    function moduleCheck(
        address _from,
        address _to,
        uint256 _value,
        address _compliance
    ) external view override returns (bool) {
        // Only need to check the recipient's accreditation for non-zero transfers
        if (_value == 0) {
            return true;
        }
        
        // Allow burns (transfers to address 0)
        if (_to == address(0)) {
            return true;
        }
        
        // All recipients must be accredited investors or exempt insiders
        return isAccreditedInvestor(_to);
    }
    
    /**
     * @dev No action required on transfer
     */
    function moduleTransferAction(address, address, uint256) external onlyComplianceCall {}
    
    /**
     * @dev No action required on mint
     */
    function moduleMintAction(address, uint256) external onlyComplianceCall {}
    
    /**
     * @dev No action required on burn
     */
    function moduleBurnAction(address, uint256) external onlyComplianceCall {}
    
    /**
     * @dev Always return true for compliance binding compatibility
     */
    function canComplianceBind(address /*_compliance*/) external view override returns (bool) {
        return true;
    }
    
    /**
     * @dev This module is plug and play and can be used without initialization
     * However, specific compliance data must be initialized through initializeModule
     */
    function isPlugAndPlay() external pure override returns (bool) {
        return true;
    }
    
    /**
     * @dev Returns the name of the module
     */
    function name() public pure override returns (string memory) {
        return "AccreditedInvestor";
    }
}