// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SecurityTokenImplementation.sol";
import "../interfaces/IComplianceModule.sol";

/// @title BaseComplianceModule
/// @notice Base contract for all compliance modules
abstract contract BaseComplianceModule is SecurityTokenImplementation, IComplianceModule {
    /// @dev Store compliance binding state with clear error messages
    mapping(address => bool) private _complianceBound;

    /// @dev Only bound compliance can call
    modifier onlyBoundCompliance() {
        require(_complianceBound[msg.sender], "Module: caller is not a bound compliance");
        _;
    }

    /// @dev Check if compliance is bound
    modifier onlyBoundComplianceParam(address compliance) {
        require(_complianceBound[compliance], "Module: compliance not bound");
        _;
    }
    
    /// @dev Initialize the base compliance module
    function __BaseComplianceModule_init(string memory _version) internal onlyInitializing {
        __SecurityTokenImplementation_init(_version, "compliance-module");
    }

    /// @notice Bind a compliance contract to this module
    /// @dev Only callable by the compliance contract itself
    function bindCompliance(address compliance) external override {
        require(compliance != address(0), "Module: compliance cannot be zero address");
        require(compliance == msg.sender, "Module: only compliance can bind itself");
        require(!_complianceBound[compliance], "Module: compliance already bound");

        _complianceBound[compliance] = true;
        // Event is emitted through the interface
        emit IComplianceModule.ComplianceBound(compliance);
    }

    /// @notice Unbind a compliance contract from this module
    /// @dev Only callable by a bound compliance contract
    function unbindCompliance(address compliance) external override onlyBoundCompliance {
        require(compliance == msg.sender, "Module: only bound compliance can unbind itself");

        _complianceBound[compliance] = false;
        // Event is emitted through the interface
        emit IComplianceModule.ComplianceUnbound(compliance);
    }

    /// @notice Initialize the module with a specific compliance
    /// @dev Optional step after binding
    function initializeModule(address compliance) external virtual override onlyBoundComplianceParam(compliance) {
        // Implement initialization logic in derived contracts
    }

    /// @notice Check if a compliance contract is bound to this module
    function isComplianceBound(address compliance) external view override returns (bool) {
        return _complianceBound[compliance];
    }
    
    /// @notice Check if a transfer complies with this module's rules
    /// @param from Address of the sender
    /// @param to Address of the receiver
    /// @param amount Amount of tokens to transfer
    /// @param compliance Address of the compliance contract making the check
    /// @return Whether the transfer is compliant with this module's rules
    function checkTransferCompliance(
        address from, 
        address to, 
        uint256 amount, 
        address compliance
    ) external virtual override onlyBoundComplianceParam(compliance) returns (bool) {
        // Default implementation, to be overridden by specific modules
        return true;
    }
    
    /**
     * @dev Legacy interface compatibility - redirects to checkTransferCompliance
     */
    function moduleCheck(
        address _from,
        address _to,
        uint256 _value,
        address _compliance
    ) external view virtual override returns (bool) {
        // This is a view function that should call checkTransferCompliance
        // Since we can't directly call an external function that might modify state,
        // we just duplicate logic or return a default value
        if (_complianceBound[_compliance]) {
            // Logic similar to checkTransferCompliance but view-only
            return true;
        }
        return false;
    }
    
    /**
     * @dev No action required on transfer
     */
    function moduleTransferAction(address, address, uint256) external virtual override onlyBoundCompliance {}
    
    /**
     * @dev No action required on mint
     */
    function moduleMintAction(address, uint256) external virtual override onlyBoundCompliance {}
    
    /**
     * @dev No action required on burn
     */
    function moduleBurnAction(address, uint256) external virtual override onlyBoundCompliance {}
    
    /**
     * @dev Always return true for compatibility
     */
    function canComplianceBind(address) external pure virtual override returns (bool) {
        return true;
    }
    
    /**
     * @dev Always return true for compatibility
     */
    function isPlugAndPlay() external pure virtual override returns (bool) {
        return true;
    }
    
    /**
     * @dev Return module name - should be overridden
     */
    function name() external pure virtual override returns (string memory) {
        return "BaseComplianceModule";
    }
}