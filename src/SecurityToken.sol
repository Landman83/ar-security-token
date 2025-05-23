// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "./interfaces/IToken.sol";
import "./storage/TokenStorage.sol";
import "./roles/AgentRoleUpgradeable.sol";
import "./proxy/SecurityTokenImplementation.sol";
import "st-identity-registry/src/interfaces/IAttributeRegistry.sol";
import "st-identity-registry/src/libraries/Attributes.sol";

contract SecurityToken is IToken, SecurityTokenImplementation, AgentRoleUpgradeable, TokenStorage {

    /// modifiers

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused() {
        require(!_tokenPaused, "Pausable: paused");
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(_tokenPaused, "Pausable: not paused");
        _;
    }

    /**
     *  @dev the constructor initiates the token contract
     *  msg.sender is set automatically as the owner of the smart contract
     *  @param _attributeRegistry the address of the Attribute registry linked to the token
     *  @param _compliance the address of the compliance contract linked to the token
     *  @param _name the name of the token
     *  @param _symbol the symbol of the token
     *  @param _decimals the decimals of the token
     *  @param _onchainID the address of the onchainID of the token
     *  emits an `UpdatedTokenInformation` event
     *  emits an `AttributeRegistryAdded` event
     *  emits a `ComplianceAdded` event
     */
    function initialize(
        address _attributeRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        // _onchainID can be zero address if not set, can be set later by owner
        address _onchainID
    ) external initializer {
        // Use the implementation's initialization
        __SecurityTokenImplementation_init(_TOKEN_VERSION, "security-token");
        __AgentRole_init();
        
        require(
            _attributeRegistry != address(0)
            && _compliance != address(0)
        , "invalid argument - zero address");
        require(
            keccak256(abi.encode(_name)) != keccak256(abi.encode(""))
            && keccak256(abi.encode(_symbol)) != keccak256(abi.encode(""))
        , "invalid argument - empty string");
        require(0 <= _decimals && _decimals <= 18, "decimals between 0 and 18");
        
        _tokenName = _name;
        _tokenSymbol = _symbol;
        _tokenDecimals = _decimals;
        _tokenOnchainID = _onchainID;
        _tokenPaused = true;
        setAttributeRegistry(_attributeRegistry);
        setCompliance(_compliance);
        
        // Initialize EIP-2612 domain separator
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(_tokenName)),
                keccak256(bytes(_TOKEN_VERSION)),
                block.chainid,
                address(this)
            )
        );
        
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    /**
     *  @dev See {IERC20-approve}.
     */
    function approve(address _spender, uint256 _amount) external virtual override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     *  @dev See {ERC20-increaseAllowance}.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + (_addedValue));
        return true;
    }

    /**
     *  @dev See {ERC20-decreaseAllowance}.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] - _subtractedValue);
        return true;
    }

    /**
     *  @dev See {IToken-setName}.
     */
    function setName(string calldata _name) external override onlyOwner {
        require(keccak256(abi.encode(_name)) != keccak256(abi.encode("")), "invalid argument - empty string");
        _tokenName = _name;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    /**
     *  @dev See {IToken-setSymbol}.
     */
    function setSymbol(string calldata _symbol) external override onlyOwner {
        require(keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")), "invalid argument - empty string");
        _tokenSymbol = _symbol;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    /**
     *  @dev See {IToken-setOnchainID}.
     *  if _onchainID is set at zero address it means no ONCHAINID is bound to this token
     */
    function setOnchainID(address _onchainID) external override onlyOwner {
        _tokenOnchainID = _onchainID;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    /**
     *  @dev See {IToken-pause}.
     */
    function pause() external override onlyAgent whenNotPaused {
        _tokenPaused = true;
        emit Paused(msg.sender);
    }

    /**
     *  @dev See {IToken-unpause}.
     */
    function unpause() external override onlyAgent whenPaused {
        _tokenPaused = false;
        emit Unpaused(msg.sender);
    }

    /**
     *  @dev See {IToken-batchTransfer}.
     */
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _toList.length; i++) {
            transfer(_toList[i], _amounts[i]);
        }
    }

    /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the from and to addresses are not frozen.
     *  Require that the value should not exceed available balance.
     *  Require that the to address is an accredited investor
     *  @param _from The address of the sender
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override whenNotPaused returns (bool) {
        require(!_frozen[_to] && !_frozen[_from], "wallet is frozen");
        require(_amount <= balanceOf(_from) - (_frozenTokens[_from]), "Insufficient Balance");
        if (_tokenAttributeRegistry.hasAttribute(_to, Attributes.ACCREDITED_INVESTOR) && _tokenCompliance.canTransfer(_from, _to, _amount)) {
            _approve(_from, msg.sender, _allowances[_from][msg.sender] - (_amount));
            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     *  @dev See {IToken-batchForcedTransfer}.
     */
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override {
        for (uint256 i = 0; i < _fromList.length; i++) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i]);
        }
    }

    /**
     *  @dev See {IToken-batchMint}.
     */
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _toList.length; i++) {
            mint(_toList[i], _amounts[i]);
        }
    }

    /**
     *  @dev See {IToken-batchBurn}.
     */
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            burn(_userAddresses[i], _amounts[i]);
        }
    }

    /**
     *  @dev See {IToken-batchSetAddressFrozen}.
     */
    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            setAddressFrozen(_userAddresses[i], _freeze[i]);
        }
    }

    /**
     *  @dev See {IToken-batchFreezePartialTokens}.
     */
    function batchFreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            freezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }

    /**
     *  @dev See {IToken-batchUnfreezePartialTokens}.
     */
    function batchUnfreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            unfreezePartialTokens(_userAddresses[i], _amounts[i]);
        }
    }
    
    /**
     * @dev Implementation of batchTransferFrom to satisfy the IToken interface
     */
    function batchTransferFrom(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override {
        require(_fromList.length == _toList.length && _toList.length == _amounts.length, "Arrays length mismatch");
        for (uint256 i = 0; i < _fromList.length; i++) {
            this.transferFrom(_fromList[i], _toList[i], _amounts[i]);
        }
    }

    /**
     *  @dev See {IToken-recoveryAddress}.
     */
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external override onlyAgent returns (bool) {
        require(balanceOf(_lostWallet) != 0, "no tokens to recover");
        
        // Ensure the new wallet is an accredited investor
        require(_tokenAttributeRegistry.hasAttribute(_newWallet, Attributes.ACCREDITED_INVESTOR), 
            "New wallet is not an accredited investor");
            
        uint256 investorTokens = balanceOf(_lostWallet);
        uint256 frozenTokens = _frozenTokens[_lostWallet];
        
        // Transfer tokens from lost wallet to new wallet
        forcedTransfer(_lostWallet, _newWallet, investorTokens);
        
        // Restore frozen tokens status if any
        if (frozenTokens > 0) {
            freezePartialTokens(_newWallet, frozenTokens);
        }
        
        // Restore frozen status if applicable
        if (_frozen[_lostWallet] == true) {
            setAddressFrozen(_newWallet, true);
        }
        
        emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
        return true;
    }

    /**
     *  @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     *  @dev See {IERC20-allowance}.
     */
    function allowance(address _owner, address _spender) external view virtual override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     *  @dev See {IToken-attributeRegistry}.
     */
    function attributeRegistry() external view override returns (IAttributeRegistry) {
        return _tokenAttributeRegistry;
    }

    /**
     *  @dev See {IToken-compliance}.
     */
    function compliance() external view override returns (IModularCompliance) {
        return _tokenCompliance;
    }

    /**
     *  @dev See {IToken-paused}.
     */
    function paused() external view override returns (bool) {
        return _tokenPaused;
    }
    
    /**
     *  @dev See {IToken-registerSTO}.
     */
    function registerSTO(address _stoContract) external override onlyOwner {
        require(_stoContract != address(0), "Invalid STO address");
        require(!_stoRegistry[_stoContract], "STO already registered");
        
        _stoRegistry[_stoContract] = true;
        _registeredSTOs.push(_stoContract);
        
        // Automatically add the STO as an agent
        if (!isAgent(_stoContract)) {
            addAgent(_stoContract);
        }
        
        emit STORegistered(_stoContract, msg.sender);
    }
    
    /**
     *  @dev See {IToken-unregisterSTO}.
     */
    function unregisterSTO(address _stoContract) external override onlyOwner {
        require(_stoRegistry[_stoContract], "STO not registered");
        
        _stoRegistry[_stoContract] = false;
        
        // Find and remove from the array
        for (uint256 i = 0; i < _registeredSTOs.length; i++) {
            if (_registeredSTOs[i] == _stoContract) {
                if (i < _registeredSTOs.length - 1) {
                    _registeredSTOs[i] = _registeredSTOs[_registeredSTOs.length - 1];
                }
                _registeredSTOs.pop();
                break;
            }
        }
        
        // Remove agent role from the STO
        if (isAgent(_stoContract)) {
            removeAgent(_stoContract);
        }
        
        emit STOUnregistered(_stoContract, msg.sender);
    }
    
    /**
     *  @dev See {IToken-isRegisteredSTO}.
     */
    function isRegisteredSTO(address _stoContract) external view override returns (bool) {
        return _stoRegistry[_stoContract];
    }
    
    /**
     *  @dev See {IToken-getRegisteredSTOs}.
     */
    function getRegisteredSTOs() external view override returns (address[] memory) {
        return _registeredSTOs;
    }

    /**
     *  @dev See {IToken-isFrozen}.
     */
    function isFrozen(address _userAddress) external view override returns (bool) {
        return _frozen[_userAddress];
    }

    /**
     *  @dev See {IToken-getFrozenTokens}.
     */
    function getFrozenTokens(address _userAddress) external view override returns (uint256) {
        return _frozenTokens[_userAddress];
    }

    /**
     *  @dev See {IToken-decimals}.
     */
    function decimals() external view override returns (uint8) {
        return _tokenDecimals;
    }

    /**
     *  @dev See {IToken-name}.
     */
    function name() external view override returns (string memory) {
        return _tokenName;
    }

    /**
     *  @dev See {IToken-onchainID}.
     */
    function onchainID() external view override returns (address) {
        return _tokenOnchainID;
    }

    /**
     *  @dev See {IToken-symbol}.
     */
    function symbol() external view override returns (string memory) {
        return _tokenSymbol;
    }

    /**
     *  @dev See {IToken-version}.
     */
    function version() external pure override returns (string memory) {
        return _TOKEN_VERSION;
    }
    
    /**
     * @dev Implementation of the EIP-2612 permit function for approval via signature
     * @param owner The address of the token owner
     * @param spender The address of the spender to be approved
     * @param value The amount of tokens to be approved
     * @param deadline The timestamp until which the signature is valid
     * @param v The recovery byte of the signature
     * @param r The first 32 bytes of the signature
     * @param s The second 32 bytes of the signature
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "SecurityToken: permit expired");
        
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner]++,
                deadline
            )
        );
        
        bytes32 hash = _hashTypedDataV4(structHash);
        
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0) && signer == owner, "SecurityToken: invalid signature");
        
        _approve(owner, spender, value);
    }
    
    /**
     * @dev Returns the current nonce for the given address
     * @param owner Address to query nonce for
     * @return Current nonce value
     */
    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }
    
    /**
     * @dev Returns the domain separator used in the encoding of the signature for permit
     * @return Domain separator
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }
    
    /**
     * @dev Helper function for hashing EIP-712 typed data
     * @param structHash The hash of the struct
     * @return The EIP-712 typed data hash
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash));
    }

    /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the msg.sender and to addresses are not frozen.
     *  Require that the value should not exceed available balance.
     *  Require that the to address is an accredited investor
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transfer(address _to, uint256 _amount) public override whenNotPaused returns (bool) {
        require(!_frozen[_to] && !_frozen[msg.sender], "wallet is frozen");
        require(_amount <= balanceOf(msg.sender) - (_frozenTokens[msg.sender]), "Insufficient Balance");
        
        // Let the compliance module handle all compliance checks
        if (_tokenCompliance.canTransfer(msg.sender, _to, _amount)) {
            _transfer(msg.sender, _to, _amount);
            _tokenCompliance.transferred(msg.sender, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     *  @dev See {IToken-forcedTransfer}.
     */
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public override onlyAgent returns (bool) {
        require(balanceOf(_from) >= _amount, "sender balance too low");
        uint256 freeBalance = balanceOf(_from) - (_frozenTokens[_from]);
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - (freeBalance);
            _frozenTokens[_from] = _frozenTokens[_from] - (tokensToUnfreeze);
            emit TokensUnfrozen(_from, tokensToUnfreeze);
        }
        
        // Let the compliance module handle all compliance checks
        if (_tokenCompliance.canTransfer(_from, _to, _amount)) {
            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     *  @dev See {IToken-mint}.
     */
    function mint(address _to, uint256 _amount) public override onlyAgent {
        // Let the compliance module handle all compliance checks
        require(_tokenCompliance.canTransfer(address(0), _to, _amount), "Compliance check failed");
        _mint(_to, _amount);
        _tokenCompliance.created(_to, _amount);
        emit Minted(_to, _amount);
    }

    /**
     *  @dev See {IToken-burn}.
     */
    function burn(address _userAddress, uint256 _amount) public override onlyAgent {
        require(balanceOf(_userAddress) >= _amount, "cannot burn more than balance");
        uint256 freeBalance = balanceOf(_userAddress) - _frozenTokens[_userAddress];
        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze = _amount - (freeBalance);
            _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (tokensToUnfreeze);
            emit TokensUnfrozen(_userAddress, tokensToUnfreeze);
        }
        _burn(_userAddress, _amount);
        _tokenCompliance.destroyed(_userAddress, _amount);
        emit Burnt(_userAddress, _amount);
    }

    /**
     *  @dev See {IToken-setAddressFrozen}.
     */
    function setAddressFrozen(address _userAddress, bool _freeze) public override onlyAgent {
        _frozen[_userAddress] = _freeze;

        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    /**
     *  @dev See {IToken-freezePartialTokens}.
     */
    function freezePartialTokens(address _userAddress, uint256 _amount) public override onlyAgent {
        uint256 balance = balanceOf(_userAddress);
        require(balance >= _frozenTokens[_userAddress] + _amount, "Amount exceeds available balance");
        _frozenTokens[_userAddress] = _frozenTokens[_userAddress] + (_amount);
        emit TokensFrozen(_userAddress, _amount);
    }

    /**
     *  @dev See {IToken-unfreezePartialTokens}.
     */
    function unfreezePartialTokens(address _userAddress, uint256 _amount) public override onlyAgent {
        require(_frozenTokens[_userAddress] >= _amount, "Amount should be less than or equal to frozen tokens");
        _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (_amount);
        emit TokensUnfrozen(_userAddress, _amount);
    }

    /**
     *  @dev See {IToken-setAttributeRegistry}.
     */
    function setAttributeRegistry(address _attributeRegistry) public override onlyOwner {
        _tokenAttributeRegistry = IAttributeRegistry(_attributeRegistry);
        emit AttributeRegistryAdded(_attributeRegistry);
    }

    /**
     *  @dev See {IToken-setCompliance}.
     */
    function setCompliance(address _compliance) public override onlyOwner {
        if (address(_tokenCompliance) != address(0)) {
            _tokenCompliance.unbindToken(address(this));
        }
        _tokenCompliance = IModularCompliance(_compliance);
        _tokenCompliance.bindToken(address(this));
        emit ComplianceAdded(_compliance);
    }

    /**
     *  @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address _userAddress) public view override returns (uint256) {
        return _balances[_userAddress];
    }

    /**
     *  @dev See {ERC20-_transfer}.
     */
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(_from, _to, _amount);

        _balances[_from] = _balances[_from] - _amount;
        _balances[_to] = _balances[_to] + _amount;
        emit Transfer(_from, _to, _amount);
    }

    /**
     *  @dev See {ERC20-_mint}.
     */
    function _mint(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), _userAddress, _amount);

        _totalSupply = _totalSupply + _amount;
        _balances[_userAddress] = _balances[_userAddress] + _amount;
        emit Transfer(address(0), _userAddress, _amount);
    }

    /**
     *  @dev See {ERC20-_burn}.
     */
    function _burn(address _userAddress, uint256 _amount) internal virtual {
        require(_userAddress != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(_userAddress, address(0), _amount);

        _balances[_userAddress] = _balances[_userAddress] - _amount;
        _totalSupply = _totalSupply - _amount;
        emit Transfer(_userAddress, address(0), _amount);
    }

    /**
     *  @dev See {ERC20-_approve}.
     */
    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /**
     *  @dev See {ERC20-_beforeTokenTransfer}.
     */
    // solhint-disable-next-line no-empty-blocks
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual {}

    /**
     * @dev Returns the balance of the token at a specific block number.
     * @param _owner The address of the token holder.
     * @param _blockNumber The block number at which to check the balance.
     * @return The balance of the token at the specified block number.
     */
    function balanceOfAt(address _owner, uint256 _blockNumber) external view override returns (uint256) {
        // Since we don't have historical balances stored, we'll return the current balance
        // In a real implementation, you would need to store snapshots of balances at different blocks
        // For now, this is a simplified implementation
        return balanceOf(_owner);
    }
}