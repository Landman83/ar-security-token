// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../roles/AgentRole.sol";
import "../token/IToken.sol";
import "../compliance/modular/IModularCompliance.sol";
import "../compliance/modular/modules/IModule.sol";
import "../proxy/authority/ITREXImplementationAuthority.sol";
import "../proxy/TokenProxy.sol";
import "../proxy/ModularComplianceProxy.sol";
import "./ITREXFactory.sol";
import "../../lib/st-identity-registry/src/interfaces/IAttributeRegistry.sol";


/**
 * @title AccreditedInvestorTokenFactory
 * @dev An updated factory for deploying tokens that use the attribute registry for compliance
 */
contract AccreditedInvestorTokenFactory is Ownable {
    /// the address of the implementation authority contract used in the tokens deployed by the factory
    address private _implementationAuthority;

    // No longer using identities

    /// mapping containing info about the token contracts corresponding to salt already used for CREATE2 deployments
    mapping(string => address) public tokenDeployed;

    /// Events
    event Deployed(address indexed _addr);
    event ImplementationAuthoritySet(address _implementationAuthority);
    event TokenDeployed(address indexed _token, address _attributeRegistry, address _mc, string indexed _salt);

    /// constructor is setting the implementation authority
    constructor(address implementationAuthority_) Ownable(msg.sender) {
        setImplementationAuthority(implementationAuthority_);
    }

    // Events to help with debugging
    event DeploymentStarted(
        string salt,
        string name,
        string symbol,
        uint8 decimals,
        address owner,
        address[] complianceModules
    );
    event ComponentDeployed(string componentName, address componentAddress);

    /**
     * @dev Deploys a token that uses the attribute registry for compliance
     * @param _salt The salt for CREATE2 deployment
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     * @param _owner Token owner
     * @param _attributeRegistry Address of the attribute registry to use
     * @param _complianceModules Array of compliance module addresses (optional)
     */
    function deployToken(
        string memory _salt, 
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner,
        address _attributeRegistry,
        address[] memory _complianceModules
    ) external onlyOwner {
        require(tokenDeployed[_salt] == address(0), "token already deployed");
        require(_owner != address(0), "invalid owner address");
        require(_attributeRegistry != address(0), "invalid attribute registry address");
        
        // Emit event for debugging
        emit DeploymentStarted(_salt, _name, _symbol, _decimals, _owner, _complianceModules);
        
        // Deploy ModularCompliance
        emit ComponentDeployed("Starting MC deployment", address(0));
        address mcAddress = _deployMC(_salt, _implementationAuthority);
        emit ComponentDeployed("MC", mcAddress);
        IModularCompliance mc = IModularCompliance(mcAddress);

        // Deploy token without onchain ID (will be created later)
        IToken token = IToken(_deployToken(
            _salt,
            _implementationAuthority,
            _attributeRegistry,
            address(mc),
            _name,
            _symbol,
            _decimals,
            address(0) // No ONCHAINID yet
        ));

        // No token identity creation - we're not using identities anymore
        
        // Setup token
        AgentRole(address(token)).addAgent(_owner);
        
        // Ensure token is bound to compliance
        mc.bindToken(address(token));
        
        // Setup compliance modules
        if (_complianceModules.length > 0) {
            // Add provided compliance modules
            for (uint256 i = 0; i < _complianceModules.length; i++) {
                if (_complianceModules[i] != address(0) && !mc.isModuleBound(_complianceModules[i])) {
                    // Add the module to compliance
                    mc.addModule(_complianceModules[i]);
                    
                    // Initialize modules via callModuleFunction if needed
                    bytes memory initializeFunctionCall = abi.encodeWithSignature("initializeModule(address)", address(mc));
                    
                    // Using try/catch with low-level call to handle modules that might not have this function
                    try mc.callModuleFunction(initializeFunctionCall, _complianceModules[i]) {
                        // Module successfully initialized
                        emit ComponentDeployed("Initialized module", _complianceModules[i]);
                    } catch {
                        // Module doesn't require initialization or doesn't support the function
                        // This is normal for plug-and-play modules
                    }
                }
            }
        }
        
        // Register the deployed token
        tokenDeployed[_salt] = address(token);
        
        // Transfer ownership of contracts to the specified owner
        (Ownable(address(token))).transferOwnership(_owner);
        (Ownable(address(mc))).transferOwnership(_owner);
        
        emit TokenDeployed(address(token), _attributeRegistry, address(mc), _salt);
    }

    /**
     * @dev Recover ownership of a contract
     */
    function recoverContractOwnership(address _contract, address _newOwner) external onlyOwner {
        (Ownable(_contract)).transferOwnership(_newOwner);
    }

    /**
     * @dev Get the implementation authority address
     */
    function getImplementationAuthority() external view returns(address) {
        return _implementationAuthority;
    }

    // No longer need ID factory getter

    /**
     * @dev Get token address for a given salt
     */
    function getToken(string calldata _salt) external view returns(address) {
        return tokenDeployed[_salt];
    }

    /**
     * @dev Set the implementation authority
     */
    function setImplementationAuthority(address implementationAuthority_) public onlyOwner {
        require(implementationAuthority_ != address(0), "invalid argument - zero address");
        // Ensure the implementation authority has token and modular compliance implementations
        require(
            (ITREXImplementationAuthority(implementationAuthority_)).getTokenImplementation() != address(0) &&
            (ITREXImplementationAuthority(implementationAuthority_)).getMCImplementation() != address(0),
            "invalid Implementation Authority");
        _implementationAuthority = implementationAuthority_;
        emit ImplementationAuthoritySet(implementationAuthority_);
    }

    // No longer need ID factory setter

    /// deploy function with create2 opcode call
    /// returns the address of the contract created
    function _deploy(string memory salt, bytes memory bytecode) private returns (address) {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, bytecode) // load initialization code.
            let encoded_size := mload(bytecode)     // load init code's length.
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr);
        return addr;
    }

    /// function used to deploy modular compliance contract using CREATE2
    function _deployMC(
        string memory _salt,
        address implementationAuthority_
    ) private returns (address) {
        bytes memory _code = type(ModularComplianceProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority_);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }

    /// function used to deploy a token using CREATE2
    function _deployToken(
        string memory _salt,
        address implementationAuthority_,
        address _attributeRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _onchainId
    ) private returns (address) {
        bytes memory _code = type(TokenProxy).creationCode;
        bytes memory _constructData = abi.encode(
            implementationAuthority_,
            _attributeRegistry,
            _compliance,
            _name,
            _symbol,
            _decimals,
            _onchainId
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }
}