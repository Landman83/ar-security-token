// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "./IModularCompliance.sol";
import "../../lib/st-identity-registry/src/interfaces/IAttributeRegistry.sol";

interface IToken {
    // ERC20 standard events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // ERC20 standard functions
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    
    // Token extensions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function onchainID() external view returns (address);
    function version() external pure returns (string memory);
    
    /**
     *  @dev transfers tokens from defaultWallet to a specific address
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     *  emits a `Transfer` event
     */
    function transfer(address _to, uint256 _amount) external returns (bool);

    /**
     *  @dev transfers token from a specific address to another address
     *  @param _from The address of the sender
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     *  emits a `Transfer` event
     */
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
    
    /**
     *  @dev batch transfers token to a specific address
     *  @param _toList The addresses of the receiver
     *  @param _amounts The number of tokens to transfer
     */
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external;

    /**
     *  @dev batch transfers token from a specific address to other specific addresses if approved
     *  @param _fromList The addresses of the sender
     *  @param _toList The addresses of the receiver
     *  @param _amounts The number of tokens to transfer
     */
    function batchTransferFrom(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;
    
    /**
     *  @dev batch forced transfers token from specific addresses to other specific addresses
     *  @param _fromList The addresses of the senders
     *  @param _toList The addresses of the receivers
     *  @param _amounts The number of tokens to transfer
     */
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;
    
    /**
     *  @dev force a transfer of tokens from a specific address to another specific address
     *  @param _from The address of the sender
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     *  This function can only be called by a wallet set as agent of the token
     *  If the from address has not enough free tokens (unfrozen tokens), the transaction will fail.
     *  However, if the from address has enough free tokens, the transfer will succeed
     *  emits a `Transfer` event
     */
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    /**
     *  @dev mint tokens on a wallet
     *  Improved version of default mint method. Tokens can be minted
     *  to an address if only it is a verified address as per the security token.
     *  @param _to Address to mint the tokens to.
     *  @param _amount Amount of tokens to mint.
     *  This function can only be called by a wallet set as agent of the token
     *  emits a `Transfer` event
     */
    function mint(address _to, uint256 _amount) external;

    /**
     *  @dev burn tokens on a wallet
     *  In case the `account` address has not enough free tokens (unfrozen tokens)
     *  but has a total balance higher or equal to the `value` amount
     *  the amount of frozen tokens is reduced in order to have enough free tokens
     *  to proceed the burn, in such a case, the remaining balance on the `account`
     *  is 100% composed of frozen tokens post-transaction.
     *  @param _userAddress Address to burn the tokens from.
     *  @param _amount Amount of tokens to burn.
     *  This function can only be called by a wallet set as agent of the token
     *  emits a `TokensUnfrozen` event if `_amount` is higher than the free balance of `_userAddress`
     *  emits a `Transfer` event
     */
    function burn(address _userAddress, uint256 _amount) external;

    /**
     *  @dev recovery function used to force transfer tokens from a
     *  lost wallet to a new wallet for an investor.
     *  @param _lostWallet the wallet that the investor lost
     *  @param _newWallet the newly provided wallet on which tokens have to be transferred
     *  @param _investorOnchainID the onchainID of the investor asking for a recovery
     *  This function can only be called by a wallet set as agent of the token
     *  emits a `TokensUnfrozen` event if there is some frozen tokens on the lost wallet if the recovery process is successful
     *  emits a `Transfer` event if the recovery process is successful
     *  emits a `RecoverySuccess` event if the recovery process is successful
     *  emits a `RecoveryFails` event if the recovery process fails
     */
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external returns (bool);

    /**
     *  @dev batch mints tokens to a set of addresses
     *  @param _toList The addresses of the receiver
     *  @param _amounts The number of tokens to mint
     */
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external;

    /**
     *  @dev batch burns tokens for a set of addresses
     *  @param _userAddresses The addresses of the wallets concerned
     *  @param _amounts The number of tokens to burn
     */
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external;

    /**
     *  @dev batch sets frozen status of a set of addresses
     *  @param _userAddresses The addresses of the wallets concerned
     *  @param _freeze Frozen status to set on each address
     */
    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external;

    /**
     *  @dev batch freezes a partial tokens for a set of addresses
     *  @param _userAddresses The addresses of the wallets concerned
     *  @param _amounts The number of tokens to freeze on each address
     */
    function batchFreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external;

    /**
     *  @dev batch unfreezes a partial tokens for a set of addresses
     *  @param _userAddresses The addresses of the wallets concerned
     *  @param _amounts The number of tokens to unfreeze on each address
     */
    function batchUnfreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external;

    /**
     * @dev Register a Security Token Offering (STO) contract that should be allowed to mint tokens
     * @param _stoContract The address of the STO contract to register
     * This function can only be called by the owner of the token
     * The STO contract will automatically be added as an agent and will be able to mint tokens
     * emits a `STORegistered` event
     */
    function registerSTO(address _stoContract) external;

    /**
     * @dev Unregister a Security Token Offering (STO) contract
     * @param _stoContract The address of the STO contract to unregister
     * This function can only be called by the owner of the token
     * The STO contract will be removed as an agent and will no longer be able to mint tokens
     * emits a `STOUnregistered` event
     */
    function unregisterSTO(address _stoContract) external;

    /**
     * @dev Check if an address is a registered STO contract
     * @param _stoContract The address to check
     * @return true if the address is a registered STO contract, false otherwise
     */
    function isRegisteredSTO(address _stoContract) external view returns (bool);

    /**
     * @dev Get the list of all registered STO contracts
     * @return Array of registered STO contract addresses
     */
    function getRegisteredSTOs() external view returns (address[] memory);

    /**
     *  @dev returns the Attribute Registry linked to the token
     *  @return the address of the Attribute Registry
     */
    function attributeRegistry() external view returns (IAttributeRegistry);

    /**
     *  @dev returns compliance contract address of the token
     *  @return the address of the compliance contract
     */
    function compliance() external view returns (IModularCompliance);

    /**
     *  @dev returns the paused status of the token
     *  @return true if the token is paused, false otherwise
     */
    function paused() external view returns (bool);

    /**
     *  @dev Returns the frozen status of a wallet
     *  @param _userAddress the address of the wallet
     *  @return the frozen status of the wallet: true if the wallet is frozen, false otherwise
     */
    function isFrozen(address _userAddress) external view returns (bool);

    /**
     *  @dev Returns the amount of tokens that are partially frozen on a wallet
     *  the amount of frozen tokens is always <= to the total balance of the wallet
     *  @param _userAddress the address of the wallet on which getFrozenTokens is called
     */
    function getFrozenTokens(address _userAddress) external view returns (uint256);

    /**
     * @dev Returns the balance of the token at a specific block number.
     * @param _owner The address of the token holder.
     * @param _blockNumber The block number at which to check the balance.
     * @return The balance of the token at the specified block number.
     */
    function balanceOfAt(address _owner, uint256 _blockNumber) external view returns (uint256);
    
    /**
     *  @dev sets an address frozen status for this token.
     *  @param _userAddress The address for which to update frozen status
     *  @param _freeze Frozen status of the address
     *  This function can only be called by a wallet set as agent of the token
     *  emits an `AddressFrozen` event
     */
    function setAddressFrozen(address _userAddress, bool _freeze) external;

    /**
     *  @dev freezes token amount specified for given address.
     *  @param _userAddress The address for which to update frozen tokens
     *  @param _amount Amount of tokens to be frozen
     *  This function can only be called by a wallet set as agent of the token
     *  emits a `TokensFrozen` event
     */
    function freezePartialTokens(address _userAddress, uint256 _amount) external;

    /**
     *  @dev unfreezes token amount specified for given address
     *  @param _userAddress The address for which to update frozen tokens
     *  @param _amount Amount of tokens to be unfrozen
     *  This function can only be called by a wallet set as agent of the token
     *  emits a `TokensUnfrozen` event
     */
    function unfreezePartialTokens(address _userAddress, uint256 _amount) external;

    /**
     *  @dev sets the token name
     *  @param _name the name of token to set
     *  Only the owner of the token smart contract can call this function
     *  emits an `UpdatedTokenInformation` event
     */
    function setName(string calldata _name) external;

    /**
     *  @dev sets the token symbol
     *  @param _symbol the token symbol to set
     *  Only the owner of the token smart contract can call this function
     *  emits an `UpdatedTokenInformation` event
     */
    function setSymbol(string calldata _symbol) external;

    /**
     *  @dev sets the onchain ID of the token
     *  @param _onchainID the address of the onchain ID to set
     *  Only the owner of the token smart contract can call this function
     *  emits an `UpdatedTokenInformation` event
     */
    function setOnchainID(address _onchainID) external;

    /**
     *  @dev sets the Attribute Registry for the token
     *  @param _attributeRegistry the address of the Attribute Registry to set
     *  Only the owner of the token smart contract can call this function
     *  emits an `AttributeRegistryAdded` event
     */
    function setAttributeRegistry(address _attributeRegistry) external;

    /**
     *  @dev sets the compliance contract of the token
     *  @param _compliance the address of the compliance contract to set
     *  Only the owner of the token smart contract can call this function
     *  calls bindToken on the compliance contract
     *  emits a `ComplianceAdded` event
     */
    function setCompliance(address _compliance) external;

    /**
     *  @dev pauses the token contract, when contract is paused investors cannot transfer tokens anymore
     *  This function can only be called by a wallet set as agent of the token
     *  emits a `Paused` event
     */
    function pause() external;

    /**
     *  @dev unpauses the token contract, when contract is unpaused investors can transfer tokens
     *  if they are not frozen and if the token controller allows it
     *  This function can only be called by a wallet set as agent of the token
     *  emits an `Unpaused` event
     */
    function unpause() external;
    
    /**
     *  this event is emitted when the token information is updated.
     *  the event is emitted by the token constructor and by the setTokenInformation function
     *  `_newName` is the name of the token
     *  `_newSymbol` is the symbol of the token
     *  `_newDecimals` is the decimals of the token
     *  `_newVersion` is the version of the token, current version is 3.0
     *  `_newOnchainID` is the address of the onchainID of the token
     */
    event UpdatedTokenInformation(string _newName, string _newSymbol, uint8 _newDecimals, string _newVersion, address _newOnchainID);

    /**
     *  this event is emitted when the AttributeRegistry has been set for the token
     *  the event is emitted by the token constructor and by the setAttributeRegistry function
     *  `_attributeRegistry` is the address of the Attribute Registry of the token
     */
    event AttributeRegistryAdded(address indexed _attributeRegistry);

    /**
     *  this event is emitted when the Compliance has been set for the token
     *  the event is emitted by the token constructor and by the setCompliance function
     *  `_compliance` is the address of the Compliance contract of the token
     */
    event ComplianceAdded(address indexed _compliance);

    /**
     *  this event is emitted when an investor successfully recovers his tokens
     *  the event is emitted by the recoveryAddress function
     *  `_lostWallet` is the address of the wallet that the investor lost access to
     *  `_newWallet` is the address of the wallet that the investor provided for the recovery
     *  `_investorOnchainID` is the address of the onchainID of the investor who asked for a recovery
     */
    event RecoverySuccess(address indexed _lostWallet, address indexed _newWallet, address indexed _investorOnchainID);

    /**
     *  this event is emitted when the token has been paused
     *  the event is emitted by the pause function
     *  `_userAddress` is the address of the wallet that called the pause function
     */
    event Paused(address indexed _userAddress);

    /**
     *  this event is emitted when the token has been unpaused
     *  the event is emitted by the unpause function
     *  `_userAddress` is the address of the wallet that called the unpause function
     */
    event Unpaused(address indexed _userAddress);

    /**
     *  this event is emitted when a wallet has been frozen
     *  the event is emitted by the setAddressFrozen function
     *  `_userAddress` is the address of the wallet that has been frozen
     *  `_isFrozen` is the status of the wallet
     *  `_owner` is the address of the wallet that called the setAddressFrozen function
     */
    event AddressFrozen(address indexed _userAddress, bool _isFrozen, address indexed _owner);

    /**
     *  this event is emitted when a agent has been frozen
     *  the event is emitted by the freezePartialTokens function
     *  `_userAddress` is the address of the wallet that has been frozen for `_amount` tokens
     *  `_amount` is the amount of tokens that have been frozen
     */
    event TokensFrozen(address indexed _userAddress, uint256 _amount);

    /**
     *  this event is emitted when a agent has been unfrozen
     *  the event is emitted by the unfreezePartialTokens function
     *  `_userAddress` is the address of the wallet that has been unfrozen for `_amount` tokens
     *  `_amount` is the amount of tokens that have been unfrozen
     */
    event TokensUnfrozen(address indexed _userAddress, uint256 _amount);

    /**
     *  this event is emitted when tokens have been minted
     *  the event is emitted by the mint function
     *  `_to` is the address of the wallet that has received the tokens
     *  `_amount` is the amount of tokens that have been minted
     */
    event Minted(address indexed _to, uint256 _amount);

    /**
     *  this event is emitted when tokens have been burnt
     *  the event is emitted by the burn function
     *  `_from` is the address of the wallet that has burnt the tokens
     *  `_amount` is the amount of tokens that have been burnt
     */
    event Burnt(address indexed _from, uint256 _amount);

    /**
     *  this event is emitted when a STO contract is registered
     *  the event is emitted by the registerSTO function
     *  `_sto` is the address of the STO contract
     *  `_owner` is the address that registered the STO contract
     */
    event STORegistered(address indexed _sto, address indexed _owner);

    /**
     *  this event is emitted when a STO contract is unregistered
     *  the event is emitted by the unregisterSTO function
     *  `_sto` is the address of the STO contract
     *  `_owner` is the address that unregistered the STO contract
     */
    event STOUnregistered(address indexed _sto, address indexed _owner);
}