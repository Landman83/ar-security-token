// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/ITREXImplementationAuthority.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IProxy.sol";
import "../../interfaces/ITREXFactory.sol";
import "../../interfaces/IIAFactory.sol";

contract TREXImplementationAuthority is ITREXImplementationAuthority, Ownable {

    /// variables

    /// current version
    Version private _currentVersion;

    /// mapping to get contracts of each version
    mapping(bytes32 => TREXContracts) private _contracts;

    /// reference ImplementationAuthority used by the TREXFactory
    bool private _reference;

    /// address of TREXFactory contract
    address private _trexFactory;

    /// address of factory for TREXImplementationAuthority contracts
    address private _iaFactory;

    /// functions

    /**
     *  @dev Constructor of the ImplementationAuthority contract
     *  @param referenceStatus boolean value determining if the contract
     *  is the main IA or an auxiliary contract
     *  @param trexFactory the address of TREXFactory referencing the main IA
     *  if `referenceStatus` is true then `trexFactory` at deployment is set
     *  on zero address. In that scenario, call `setTREXFactory` post-deployment
     *  @param iaFactory the address for the factory of IA contracts
     *  emits `ImplementationAuthoritySet` event
     *  emits a `IAFactorySet` event
     */
    constructor (bool referenceStatus, address trexFactory, address iaFactory) Ownable(msg.sender) {
        _reference = referenceStatus;
        _trexFactory = trexFactory;
        _iaFactory = iaFactory;
        emit ImplementationAuthoritySet(referenceStatus, trexFactory);
        emit IAFactorySet(iaFactory);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-setTREXFactory}.
     */
    function setTREXFactory(address trexFactory) external override onlyOwner {
        require(
            isReferenceContract() &&
            ITREXFactory(trexFactory).getImplementationAuthority() == address(this)
        , "only reference contract can call");
        _trexFactory = trexFactory;
        emit TREXFactorySet(trexFactory);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-setIAFactory}.
     */
    function setIAFactory(address iaFactory) external override onlyOwner {
        require(
            isReferenceContract() &&
            ITREXFactory(_trexFactory).getImplementationAuthority() == address(this)
        , "only reference contract can call");
        _iaFactory = iaFactory;
        emit IAFactorySet(iaFactory);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-useTREXVersion}.
     */
    function addAndUseTREXVersion(Version calldata _version, TREXContracts calldata _trex) external override {
        addTREXVersion(_version, _trex);
        useTREXVersion(_version);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-fetchVersionList}.
     */
    function fetchVersion(Version calldata _version) external override {
        require(!isReferenceContract(), "cannot call on reference contract");
        if (_contracts[_versionToBytes(_version)].tokenImplementation != address(0)) {
            revert("version fetched already");
        }
        _contracts[_versionToBytes(_version)] =
        ITREXImplementationAuthority(getReferenceContract()).getContracts(_version);
        emit TREXVersionFetched(_version, _contracts[_versionToBytes(_version)]);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-changeImplementationAuthority}.
     */
    // solhint-disable-next-line code-complexity, function-max-lines
    function changeImplementationAuthority(address _token, address _newImplementationAuthority) external override {
        require(_token != address(0), "invalid argument - zero address");
        if(_newImplementationAuthority == address(0) && !isReferenceContract()){
            revert("only reference contract can deploy new IAs");}

        address _ar = address(IToken(_token).attributeRegistry());
        address _mc = address(IToken(_token).compliance());

        // Get the ModularActions address associated with the token
        address _ma = address(0);
        // Try to find ModularActions by checking tokenDeploy mapping in TREXFactory
        ITREXFactory factory = ITREXFactory(_trexFactory);
        
        // Get the owner of ModularActions if it exists (check will be performed later)
        address maOwner = address(0);
        try Ownable(_ma).owner() returns (address _owner) {
            maOwner = _owner;
        } catch {}
        
        // calling this function requires ownership of ALL contracts of the T-REX suite
        if(
            Ownable(_token).owner() != msg.sender
            || Ownable(_ar).owner() != msg.sender
            || Ownable(_mc).owner() != msg.sender
            || (_ma != address(0) && maOwner != address(0) && maOwner != msg.sender)) {
            revert("caller NOT owner of all contracts impacted");
        }

        if(_newImplementationAuthority == address(0)) {
            _newImplementationAuthority = IIAFactory(_iaFactory).deployIA(_token);
        }
        else {
            if(
                _versionToBytes(ITREXImplementationAuthority(_newImplementationAuthority).getCurrentVersion()) !=
                _versionToBytes(_currentVersion)) {
                revert("version of new IA has to be the same as current IA");
            }
            if(
                ITREXImplementationAuthority(_newImplementationAuthority).isReferenceContract() &&
                _newImplementationAuthority != getReferenceContract()) {
                revert("new IA is NOT reference contract");
            }
            if(
                !IIAFactory(_iaFactory).deployedByFactory(_newImplementationAuthority) &&
            _newImplementationAuthority != getReferenceContract()) {
                revert("invalid IA");
            }
        }

        IProxy(_token).setImplementationAuthority(_newImplementationAuthority);
        // Attempt to set implementation authority for attribute registry if it's a proxy
        try IProxy(_ar).setImplementationAuthority(_newImplementationAuthority) {} catch {}
        IProxy(_mc).setImplementationAuthority(_newImplementationAuthority);
        // Set implementation authority for ModularActions if it exists
        if (_ma != address(0)) {
            try IProxy(_ma).setImplementationAuthority(_newImplementationAuthority) {} catch {}
        }
        emit ImplementationAuthorityChanged(_token, _newImplementationAuthority);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getCurrentVersion}.
     */
    function getCurrentVersion() external view override returns (Version memory) {
        return _currentVersion;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getContracts}.
     */
    function getContracts(Version calldata _version) external view override returns (TREXContracts memory) {
        return _contracts[_versionToBytes(_version)];
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getTREXFactory}.
     */
    function getTREXFactory() external view override returns (address) {
        return _trexFactory;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getTokenImplementation}.
     */
    function getTokenImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].tokenImplementation;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getCTRImplementation}.
     */
    function getCTRImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].ctrImplementation;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getIRImplementation}.
     */
    function getIRImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].irImplementation;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getIRSImplementation}.
     */
    function getIRSImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].irsImplementation;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getTIRImplementation}.
     */
    function getTIRImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].tirImplementation;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getMCImplementation}.
     */
    function getMCImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].mcImplementation;
    }
    
    /**
     *  @dev See {ITREXImplementationAuthority-getMAImplementation}.
     */
    function getMAImplementation() external view override returns (address) {
        return _contracts[_versionToBytes(_currentVersion)].maImplementation;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-addTREXVersion}.
     */
    function addTREXVersion(Version calldata _version, TREXContracts calldata _trex) public override onlyOwner {
        require(isReferenceContract(), "ONLY reference contract can add versions");
        if (_contracts[_versionToBytes(_version)].tokenImplementation != address(0)) {
            revert("version already exists");
        }
        require(
            _trex.ctrImplementation != address(0)
            && _trex.irImplementation != address(0)
            && _trex.irsImplementation != address(0)
            && _trex.mcImplementation != address(0)
            && _trex.tirImplementation != address(0)
            && _trex.tokenImplementation != address(0)
            && _trex.maImplementation != address(0)
        , "invalid argument - zero address");
        _contracts[_versionToBytes(_version)] = _trex;
        emit TREXVersionAdded(_version, _trex);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-useTREXVersion}.
     */
    function useTREXVersion(Version calldata _version) public override onlyOwner {
        if (_versionToBytes(_version) == _versionToBytes(_currentVersion)) {
            revert("version already in use");
        }
        if (_contracts[_versionToBytes(_version)].tokenImplementation == address(0)) {
            revert("invalid argument - non existing version");
        }
        _currentVersion = _version;
        emit VersionUpdated(_version);
    }

    /**
     *  @dev See {ITREXImplementationAuthority-isReferenceContract}.
     */
    function isReferenceContract() public view override returns (bool) {
        return _reference;
    }

    /**
     *  @dev See {ITREXImplementationAuthority-getReferenceContract}.
     */
    function getReferenceContract() public view override returns (address) {
        return ITREXFactory(_trexFactory).getImplementationAuthority();
    }

    /**
     *  @dev casting function Version => bytes to allow compare values easier
     */
    function _versionToBytes(Version memory _version) private pure returns(bytes32) {
        return bytes32(keccak256(abi.encodePacked(_version.major, _version.minor, _version.patch)));
    }
}