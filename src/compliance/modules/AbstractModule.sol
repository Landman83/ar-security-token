// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "../../interfaces/IComplianceModule.sol";

abstract contract AbstractModule is IComplianceModule {

    /// compliance contract binding status
    mapping(address => bool) private _complianceBound;
    
    // No need to redefine events since they're already defined in IComplianceModule

    /**
     * @dev Throws if `_compliance` is not a bound compliance contract address.
     */
    modifier onlyBoundCompliance(address _compliance) {
        require(_complianceBound[_compliance], "compliance not bound");
        _;
    }

    /**
     * @dev Throws if called from an address that is not a bound compliance contract.
     */
    modifier onlyComplianceCall() {
        require(_complianceBound[msg.sender], "only bound compliance can call");
        _;
    }

    /**
     *  @dev See {IModule-bindCompliance}.
     */
    function bindCompliance(address _compliance) external override {
        require(_compliance != address(0), "invalid argument - zero address");
        require(!_complianceBound[_compliance], "compliance already bound");
        require(msg.sender == _compliance, "only compliance contract can call");
        _complianceBound[_compliance] = true;
        emit ComplianceBound(_compliance);
    }

    /**
     *  @dev See {IModule-unbindCompliance}.
     */
    function unbindCompliance(address _compliance) external onlyComplianceCall override {
        require(_compliance != address(0), "invalid argument - zero address");
        require(msg.sender == _compliance, "only compliance contract can call");
        _complianceBound[_compliance] = false;
        emit ComplianceUnbound(_compliance);
    }

    /**
     *  @dev See {IModule-isComplianceBound}.
     */
    function isComplianceBound(address _compliance) external view override returns (bool) {
        return _complianceBound[_compliance];
    }
    
    /**
     *  @dev New method for checking transfer compliance that can modify state if needed
     *  Default implementation returns true and should be overridden by child contracts
     */
    function checkTransferCompliance(
        address from,
        address to,
        uint256 amount,
        address compliance
    ) external virtual override onlyBoundCompliance(compliance) returns (bool) {
        // Default implementation returns the result of moduleCheck
        return this.moduleCheck(from, to, amount, compliance);
    }
    
    /**
     *  @dev Initialize the module with specific compliance settings
     *  Default implementation does nothing and should be overridden if needed
     */
    function initializeModule(address compliance) external virtual override onlyComplianceCall {
        // Default implementation does nothing
    }
    
    /**
     *  @dev checks whether compliance is suitable to bind to the module.
     *  Default implementation always returns true
     */
    function canComplianceBind(address /*_compliance*/) external view virtual override returns (bool) {
        return true;
    }
    
    /**
     *  @dev getter for module plug & play status
     *  Default to true for AbstractModule
     */
    function isPlugAndPlay() external pure virtual override returns (bool) {
        return true;
    }

}
