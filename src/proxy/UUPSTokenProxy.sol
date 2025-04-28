// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title UUPSTokenProxy
/// @notice UUPS Proxy for security tokens with better context preservation
contract UUPSTokenProxy {
    /// @dev Storage slot for implementation address (EIP-1967)
    bytes32 private constant IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        
    /// @dev Event emitted when the implementation is upgraded
    event Upgraded(address indexed implementation);

    /// @notice Initializes the proxy with an implementation contract and initialization data
    /// @param _implementation Address of the initial implementation
    /// @param _initData Initialization data to be passed to the implementation
    constructor(address _implementation, bytes memory _initData) {
        _updateImplementation(_implementation);
        
        if (_initData.length > 0) {
            // Call the initialize function on the implementation
            (bool success, ) = _implementation.delegatecall(_initData);
            if (!success) {
                assembly {
                    let ptr := mload(0x40)
                    let size := returndatasize()
                    returndatacopy(ptr, 0, size)
                    revert(ptr, size)
                }
            }
        }
    }

    /// @dev Delegates execution to the implementation contract
    fallback() external payable {
        address implementation = _getImplementation();
        
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code.
            calldatacopy(0, 0, calldatasize())
            
            // Call the implementation with perfect context preservation
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            
            // Copy the returned data
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    /// @dev Receives ETH transfers
    receive() external payable {}
    
    /// @dev Get current implementation
    function _getImplementation() private view returns (address implementation) {
        assembly {
            implementation := sload(IMPLEMENTATION_SLOT)
        }
    }
    
    /// @dev Update implementation
    function _updateImplementation(address newImplementation) private {
        require(newImplementation != address(0), "Implementation cannot be zero address");
        
        // Check that the implementation is a contract by checking its code size
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(newImplementation)
        }
        require(codeSize > 0, "Implementation must be a contract");
        
        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
        
        emit Upgraded(newImplementation);
    }
}