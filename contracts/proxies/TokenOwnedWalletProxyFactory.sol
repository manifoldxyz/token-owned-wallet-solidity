// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "./TokenOwnedWalletProxy.sol";

library TokenOwnedWalletProxyFactory {
    event ProxyCreation(address proxy, address implementation);

    /**
     * @dev Allows to create new proxy contact.
     * @param implementation Address of the implementation contract.
     * @param salt Salt used to generate the proxy contract address.
     */
    function createProxy(address implementation, bytes32 salt) public returns (address proxy) {
        bytes memory bytecode = abi.encodePacked(
            type(TokenOwnedWalletProxy).creationCode,
            uint256(uint160(implementation))
        );
        
        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := create2(0x0, add(0x20, bytecode), mload(bytecode), salt)
        }

        emit ProxyCreation(proxy, implementation);
    }
}
