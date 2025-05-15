// SPDX-License-Identifier: GPL-3.0


pragma solidity ^0.8.17;
import "../interfaces/IModularCompliance.sol";
import "../../lib/st-identity-registry/src/interfaces/IAttributeRegistry.sol";


contract TokenStorage {
    /// @dev ERC20 basic variables
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    /// @dev Token information
    string internal _tokenName;
    string internal _tokenSymbol;
    uint8 internal _tokenDecimals;
    address internal _tokenOnchainID;
    string internal constant _TOKEN_VERSION = "4.1.3";

    /// @dev Variables of freeze and pause functions
    mapping(address => bool) internal _frozen;
    mapping(address => uint256) internal _frozenTokens;

    bool internal _tokenPaused = false;

    /// @dev Attribute Registry contract used for compliance checks
    IAttributeRegistry internal _tokenAttributeRegistry;

    /// @dev Compliance contract linked to the compliance system
    IModularCompliance internal _tokenCompliance;
    
    /// @dev List of registered STO contracts that have minting permissions
    address[] internal _registeredSTOs;
    
    /// @dev Mapping of registered STO contracts for quick lookup
    mapping(address => bool) internal _stoRegistry;

    /// @dev EIP-2612 permit related storage
    bytes32 internal _DOMAIN_SEPARATOR;
    bytes32 internal constant _PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) internal _nonces;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[46] private __gap; // Reduced from 49 to 46 to account for the 3 new variables
}
