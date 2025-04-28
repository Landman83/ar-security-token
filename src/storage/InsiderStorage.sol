// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

/**
 * @title InsiderStorage
 * @dev Storage contract for the InsiderRegistry that defines the storage layout and provides
 * getter and setter functions for insider data.
 */
library InsiderStorage {
    struct Layout {
        // Mapping to track insider status (address => is insider)
        mapping(address => bool) insiders;
        
        // Mapping to track insider type (address => type)
        mapping(address => uint8) insiderTypes;
        
        // Array to track all insider addresses
        address[] insiderList;
        
        // Mapping to track insiders by type (type => array of addresses)
        mapping(uint8 => address[]) insidersByType;
    }

    // Storage slot
    bytes32 internal constant STORAGE_SLOT = keccak256("storage.insiders.registry");

    /**
     * @dev Returns the storage reference
     */
    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    /**
     * @dev Checks if an address is an insider
     * @param _wallet The address to check
     * @return bool True if the address is an insider
     */
    function isInsider(Layout storage l, address _wallet) internal view returns (bool) {
        return l.insiders[_wallet];
    }

    /**
     * @dev Gets the insider type for an address
     * @param _wallet The address to check
     * @return uint8 The insider type
     */
    function getInsiderType(Layout storage l, address _wallet) internal view returns (uint8) {
        return l.insiderTypes[_wallet];
    }

    /**
     * @dev Adds an insider
     * @param _wallet The address to register as an insider
     * @param _insiderType The type of insider
     */
    function addInsider(Layout storage l, address _wallet, uint8 _insiderType) internal {
        // Set insider status and type
        l.insiders[_wallet] = true;
        l.insiderTypes[_wallet] = _insiderType;
        
        // Add to global insider list
        l.insiderList.push(_wallet);
        
        // Add to type-specific list
        l.insidersByType[_insiderType].push(_wallet);
    }

    /**
     * @dev Removes an insider
     * @param _wallet The address to remove
     */
    function removeInsider(Layout storage l, address _wallet) internal {
        uint8 insiderType = l.insiderTypes[_wallet];
        
        // Remove insider status and type
        delete l.insiders[_wallet];
        delete l.insiderTypes[_wallet];
        
        // Remove from global insider list (we don't preserve order)
        for (uint256 i = 0; i < l.insiderList.length; i++) {
            if (l.insiderList[i] == _wallet) {
                l.insiderList[i] = l.insiderList[l.insiderList.length - 1];
                l.insiderList.pop();
                break;
            }
        }
        
        // Remove from type-specific list (we don't preserve order)
        address[] storage typeList = l.insidersByType[insiderType];
        for (uint256 i = 0; i < typeList.length; i++) {
            if (typeList[i] == _wallet) {
                typeList[i] = typeList[typeList.length - 1];
                typeList.pop();
                break;
            }
        }
    }

    /**
     * @dev Updates an insider's type
     * @param _wallet The address to update
     * @param _newType The new insider type
     */
    function updateInsiderType(Layout storage l, address _wallet, uint8 _newType) internal {
        uint8 oldType = l.insiderTypes[_wallet];
        
        // Skip if type is not changing
        if (oldType == _newType) {
            return;
        }
        
        // Update insider type
        l.insiderTypes[_wallet] = _newType;
        
        // Remove from old type list
        address[] storage oldTypeList = l.insidersByType[oldType];
        for (uint256 i = 0; i < oldTypeList.length; i++) {
            if (oldTypeList[i] == _wallet) {
                oldTypeList[i] = oldTypeList[oldTypeList.length - 1];
                oldTypeList.pop();
                break;
            }
        }
        
        // Add to new type list
        l.insidersByType[_newType].push(_wallet);
    }

    /**
     * @dev Gets all insiders
     * @return Array of insider addresses
     */
    function getInsiders(Layout storage l) internal view returns (address[] memory) {
        return l.insiderList;
    }

    /**
     * @dev Gets all insiders of a specific type
     * @param _type The insider type
     * @return Array of insider addresses of the specified type
     */
    function getInsidersByType(Layout storage l, uint8 _type) internal view returns (address[] memory) {
        return l.insidersByType[_type];
    }
}