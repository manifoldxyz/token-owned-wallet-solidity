// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/StorageSlot.sol";

contract Migration {
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public immutable migrationSingleton;
    address public immutable _targetImplementation;

    constructor(address targetImplementation) {
        require(targetImplementation != address(0), "Invalid address");
        _targetImplementation = targetImplementation;
        migrationSingleton = address(this);
    }

    /**
     * @dev Allows wallet implementation upgrade. This can only be called via a delegatecall.
     */
    function migrate() public {
        require(address(this) != migrationSingleton, "Must call via delegatecall");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = _targetImplementation;
    }
}
