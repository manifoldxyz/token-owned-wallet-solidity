// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "./TokenOwnedWalletProxy.sol";

library TokenOwnedWalletProxyFactory {
    event AccountCreated(
        address account,
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    );

    /**
     * @dev Allows to create new proxy contact.
     * @param implementation Address of the implementation contract.
     * @param salt Salt used to generate the proxy contract address.
     */
    function createProxy(uint256 chainId, address contractAddress, uint256 tokenId, address implementation, bytes32 salt) public returns (address proxy) {
        bytes memory bytecode = abi.encodePacked(
            type(TokenOwnedWalletProxy).creationCode
        );

        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := create2(0x0, add(0x20, bytecode), mload(bytecode), salt)
        }
        (bool success, bytes memory data) = proxy.call(
            abi.encodeWithSignature("initialize(uint256,address,uint256,address)", chainId, contractAddress, tokenId, implementation)
        );
        require(success, string(data));

        emit AccountCreated(proxy, implementation, chainId, contractAddress, tokenId);
    }
}
