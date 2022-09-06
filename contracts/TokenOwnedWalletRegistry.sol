// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/Create2.sol";
import "./proxies/TokenOwnedWalletProxyFactory.sol";
import "./TokenOwnedWallet.sol";

/**
 * @title TokenOwnedWalletRegistry
 * @notice A registry used to create and map token wallet instances to tokens.
 */
contract TokenOwnedWalletRegistry {

    address private immutable _tokenWalletImplementation;

    // A mapping from salt (used for contract creation) to token wallet address
    mapping(bytes32 => address) private _saltToAddress;

    uint256[50] private __gap;

    /**
     * Constructor
     */
    constructor(address tokenWalletImplementation) {
        _tokenWalletImplementation = tokenWalletImplementation;
    }

    /**
     * @notice Creates a new wallet instance for the provided token's contract address and token
     * ID if a wallet doesn't already exist.
     * @param contractAddress The token's contract address.
     * @param tokenId The token's ID.
     * @return address - The address of the new or current wallet address.
     */
    function create(address contractAddress, uint256 tokenId) external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(contractAddress, tokenId));

        // Return backpack address if it already exists.
        if (_saltToAddress[salt] != address(0)) {
            return _saltToAddress[salt];
        }

        address proxy = TokenOwnedWalletProxyFactory.createProxy(
            _tokenWalletImplementation,
            salt
        );

        TokenOwnedWallet(proxy).initialize(contractAddress, tokenId);

        _saltToAddress[salt] = proxy;
        return proxy;
    }

    /**
     * @notice Provides the address of the wallet related to the token.
     * @param contractAddress The token's contract address.
     * @param tokenId The token's ID.
     * @return address - The wallet address, or address(0) if the wallet doesn't exist.
     */
    function addressOf(address contractAddress, uint256 tokenId) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(contractAddress, tokenId));
        return _saltToAddress[salt];
    }

    /**
     * @notice Checks if a token has a registered wallet address.
     * @param contractAddress The token's contract address.
     * @param tokenId The token's ID.
     * @return bool - Whether or not the address exists.
     */
    function addressExists(address contractAddress, uint256 tokenId) public view returns (bool) {
        return addressOf(contractAddress, tokenId) != address(0);
    }
}
