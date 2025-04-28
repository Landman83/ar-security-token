// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./roles/AgentRole.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IModularCompliance.sol";
import "./interfaces/IComplianceModule.sol";
import "./interfaces/ITREXFactory.sol";
import "./proxy/VersionRegistry.sol";
import "./proxy/UUPSTokenProxy.sol";
import "./proxy/ComplianceModuleProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "st-identity-registry/src/interfaces/IAttributeRegistry.sol";

/**
 * @title RefactoredSecurityTokenFactory
 * @dev A factory using modern proxy architecture for deploying security tokens
 */
contract RefactoredSecurityTokenFactory is Ownable {
    /// Version registry for tracking implementations
    VersionRegistry public immutable registry;

    /// mapping containing info about the token contracts corresponding to salt already used for CREATE2 deployments
    mapping(string => address) public tokenDeployed;

    /// Events
    event TokenDeployed(address indexed _token, address _attributeRegistry, address _mc, string indexed _salt);
    event ModuleDeployed(address indexed _module, string moduleType, string version);

    /// constructor is setting the version registry
    constructor(address registry_) Ownable(msg.sender) {
        require(registry_ != address(0), "invalid argument - zero address");
        registry = VersionRegistry(registry_);
    }

    /**
     * @dev Deploys a token that uses the attribute registry for compliance
     * @param _salt The salt for CREATE2 deployment
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     * @param _owner Token owner
     * @param _attributeRegistry Address of the attribute registry to use
     * @param _complianceModules Array of compliance module addresses (optional)
     * @param _tokenVersion Version of the token implementation to use
     * @param _complianceVersion Version of the compliance implementation to use
     */
    function deployToken(
        string memory _salt, 
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        address _attributeRegistry,
        address[] memory _complianceModules,
        string memory _tokenVersion,
        string memory _complianceVersion
    ) external onlyOwner {
        require(tokenDeployed[_salt] == address(0), "token already deployed");
        require(_owner != address(0), "invalid owner address");
        require(_attributeRegistry != address(0), "invalid attribute registry address");
        
        // Deploy ModularCompliance
        address mcAddress = deployModularCompliance(_complianceVersion);
        IModularCompliance mc = IModularCompliance(mcAddress);

        // Deploy token
        address token = deployTokenWithCompliance(
            _name,
            _symbol,
            _decimals,
            mcAddress,
            _attributeRegistry,
            address(0), // No ONCHAINID
            _tokenVersion
        );
        
        // Setup token
        AgentRole(token).addAgent(_owner);
        
        // Ensure token is bound to compliance
        mc.bindToken(token);
        
        // Setup compliance modules if any are provided
        if (_complianceModules.length > 0) {
            for (uint256 i = 0; i < _complianceModules.length; i++) {
                if (_complianceModules[i] != address(0) && !mc.isModuleBound(_complianceModules[i])) {
                    mc.addModule(_complianceModules[i]);
                    
                    // Try to initialize the module with the compliance
                    bytes memory initData = abi.encodeWithSignature(
                        "initializeModule(address)",
                        mcAddress
                    );
                    
                    try mc.callModuleFunction(initData, _complianceModules[i]) {
                        // Module initialized successfully
                    } catch {
                        // Module doesn't need initialization or failed to initialize
                    }
                }
            }
        }
        
        // Register the deployed token
        tokenDeployed[_salt] = token;
        
        // Transfer ownership to the specified owner
        Ownable(token).transferOwnership(_owner);
        Ownable(mcAddress).transferOwnership(_owner);
        
        emit TokenDeployed(token, _attributeRegistry, mcAddress, _salt);
    }

    /**
     * @dev Deploy a compliance module
     * @param _moduleType The type of module to deploy
     * @param _version The version of the module to deploy
     * @param _initData The initialization data for the module
     */
    function deployComplianceModule(
        string calldata _moduleType,
        string calldata _version,
        bytes calldata _initData
    ) public returns (address) {
        address implementation = registry.getImplementation(_moduleType, _version);
        require(implementation != address(0), "Implementation not found");
        require(!registry.isDeprecated(_moduleType, _version), "Implementation deprecated");
        
        // Deploy ComplianceModuleProxy
        ComplianceModuleProxy proxy = new ComplianceModuleProxy(
            implementation,
            _initData
        );
        
        emit ModuleDeployed(address(proxy), _moduleType, _version);
        return address(proxy);
    }

    /**
     * @dev Deploy modular compliance
     * @param _version The version of the compliance to deploy
     */
    function deployModularCompliance(string memory _version) public returns (address) {
        address implementation = registry.getImplementation("modular-compliance", _version);
        require(implementation != address(0), "MC implementation not found");
        require(!registry.isDeprecated("modular-compliance", _version), "MC implementation deprecated");
        
        // Create initialization data
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize()")));
        
        // Deploy UUPS proxy
        ComplianceModuleProxy proxy = new ComplianceModuleProxy(
            implementation,
            initData
        );
        
        return address(proxy);
    }

    /**
     * @dev Deploy token with compliance
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     * @param _compliance Compliance address
     * @param _attributeRegistry Attribute registry address
     * @param _onchainID OnchainID address (can be zero)
     * @param _version The version of the token to deploy
     */
    function deployTokenWithCompliance(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _compliance,
        address _attributeRegistry,
        address _onchainID,
        string memory _version
    ) public returns (address) {
        address implementation = registry.getImplementation("security-token", _version);
        require(implementation != address(0), "Token implementation not found");
        require(!registry.isDeprecated("security-token", _version), "Token implementation deprecated");
        
        // Create initialization data
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("initialize(address,address,string,string,uint8,address)")),
            _attributeRegistry,
            _compliance,
            _name,
            _symbol,
            _decimals,
            _onchainID
        );
        
        // Deploy UUPSTokenProxy
        UUPSTokenProxy proxy = new UUPSTokenProxy(
            implementation,
            initData
        );
        
        return address(proxy);
    }

    /**
     * @dev Get token address for a given salt
     */
    function getToken(string calldata _salt) external view returns(address) {
        return tokenDeployed[_salt];
    }
}