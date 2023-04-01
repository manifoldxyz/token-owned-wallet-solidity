// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./lib/TokenOwnedWalletBytecode.sol";

/**
 * @title TokenOwnedWalletRegistry
 * @notice A registry used to create and map token wallet instances to tokens.
 */
contract TokenOwnedWalletRegistry {

    event AccountCreated(
        address account,
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 index
    );

    /**
     * @notice Creates a new wallet instance for the provided token's contract address and token
     * ID if a wallet doesn't already exist.
     *
     * @param chainId The token's chain ID.
     * @param contractAddress The token's contract address.
     * @param tokenId The token's ID.
     * @return address - The address of the new or current wallet address.
     */
    function create(
        address implementation,
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint256 index,
        bytes calldata initdata
    ) external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(implementation, chainId, contractAddress, tokenId, index));
        bytes memory code = TokenOwnedWalletBytecode.createCode(implementation, chainId, contractAddress, tokenId, index);
        address wallet = Create2.deploy(0, salt, code);
        if (initdata.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = wallet.call(initdata);
            require(success, "TokenOwnedWalletRegistry: Failed to initialize wallet");
        }
        emit AccountCreated(wallet, implementation, chainId, contractAddress, tokenId, index);
        return wallet;
    }

    /**
     * @notice Provides the address of the wallet related to the token.
     * @param contractAddress The token's contract address.
     * @param chainId The token's chain ID.
     * @param tokenId The token's ID.
     * @return address - The wallet address, or address(0) if the wallet doesn't exist.
     */
    function addressOf(
        address implementation,
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint256 index
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(implementation, chainId, contractAddress, tokenId, index));
        bytes memory code = TokenOwnedWalletBytecode.createCode(implementation, chainId, contractAddress, tokenId, index);
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(code))
        );
        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }

}
