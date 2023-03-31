// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./proxies/TokenOwnedWalletProxy.sol";
import "./proxies/TokenOwnedWalletProxyFactory.sol";
import "./TokenOwnedWallet.sol";

interface IProxy {
    function implementation() external view returns (address);
}

struct TokenOwnedWalletImplementation {
    string version;
    address implementation;
}

/**
 * @title TokenOwnedWalletRegistry
 * @notice A registry used to create and map token wallet instances to tokens.
 */
contract TokenOwnedWalletRegistry is Ownable {
    address private _currentImplementation;

    TokenOwnedWalletImplementation[] private _versionHistory;

    // A mapping from salt (used for contract creation) to token wallet address
    mapping(bytes32 => address) private _saltToAddress;

    uint256[50] private __gap;

    /**
     * Constructor
     */
    constructor(address tokenWalletImplementation) {
        _currentImplementation = tokenWalletImplementation;
        _versionHistory.push(
            TokenOwnedWalletImplementation({
                version: "1.0.0",
                implementation: tokenWalletImplementation
            })
        );
    }

    /**
     * @notice Creates a new wallet instance for the provided token's contract address and token
     * ID if a wallet doesn't already exist.
     *
     * @param chainId The token's chain ID.
     * @param contractAddress The token's contract address.
     * @param tokenId The token's ID.
     * @return address - The address of the new or current wallet address.
     */
    function create(uint256 chainId, address contractAddress, uint256 tokenId) external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, contractAddress, tokenId));

        // Return backpack address if it already exists.
        if (_saltToAddress[salt] != address(0)) {
            return _saltToAddress[salt];
        }

        address proxy = TokenOwnedWalletProxyFactory.createProxy(chainId, contractAddress, tokenId, _currentImplementation, salt);
        _saltToAddress[salt] = proxy;
        return proxy;
    }

    /**
     * @notice Provides the address of the wallet related to the token.
     * @param contractAddress The token's contract address.
     * @param chainId The token's chain ID.
     * @param tokenId The token's ID.
     * @return address - The wallet address, or address(0) if the wallet doesn't exist.
     */
    function addressOf(uint256 chainId, address contractAddress, uint256 tokenId) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, contractAddress, tokenId));
        return _saltToAddress[salt];
    }

    /**
     * @notice Checks if a token has a registered wallet address.
     * @param contractAddress The token's contract address.
     * @param chainId The token's chain ID.
     * @param tokenId The token's ID.
     * @return bool - Whether or not the address exists.
     */
    function addressExists(uint256 chainId, address contractAddress, uint256 tokenId) public view returns (bool) {
        return addressOf(chainId, contractAddress, tokenId) != address(0);
    }

    /**
     * @notice Returns the wallet implementation owned by the provided token.
     * @param contractAddress The token's contract address.
     * @param chainId The token's chain ID.
     * @param tokenId The token's ID.
     * @return TokenOwnedWalletImplementation - the implementation used by the token's wallet.
     */
    function implementationOf(uint256 chainId, address contractAddress, uint256 tokenId)
        public
        view
        returns (TokenOwnedWalletImplementation memory)
    {
        require(addressExists(chainId, contractAddress, tokenId), "No wallet found");
        address implementation = IProxy(addressOf(chainId, contractAddress, tokenId)).implementation();
        for (uint256 i = 0; i < _versionHistory.length; i++) {
            if (implementation == _versionHistory[i].implementation) {
                return _versionHistory[i];
            }
        }
        revert("Unsupported version");
    }

    /**
     * @notice Publishes a new token wallet implementation.
     * @param version A string representation of the version (e.g "1.0.2").
     * @param implementation The address of the implementation contract.
     */
    function publishImplementation(string calldata version, address implementation)
        public
        onlyOwner
    {
        _versionHistory.push(
            TokenOwnedWalletImplementation({version: version, implementation: implementation})
        );
    }
}
