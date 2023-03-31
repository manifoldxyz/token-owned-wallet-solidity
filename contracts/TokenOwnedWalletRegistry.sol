// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

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
    address public immutable proxyImplementation;
    address public currentImplementation;

    TokenOwnedWalletImplementation[] private _versionHistory;

    // A mapping from salt (used for contract creation) to token wallet address
    mapping(bytes32 => address) private _saltToAddress;

    event AccountCreated(
        address account,
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    );

    /**
     * Constructor
     */
    constructor(address _proxyImplementation, address _initialImplementation) {
        proxyImplementation = _proxyImplementation;
        currentImplementation = _initialImplementation;
        _versionHistory.push(
            TokenOwnedWalletImplementation({
                version: "1.0.0",
                implementation: currentImplementation
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

        address proxy = _createProxy(proxyImplementation, chainId, contractAddress, tokenId, currentImplementation, salt);
        _saltToAddress[salt] = proxy;
        return proxy;
    }

    /**
     * @dev Allows to create new proxy contact.
     * @param implementation Address of the implementation contract.
     * @param salt Salt used to generate the proxy contract address.
     */
    function _createProxy(address clone, uint256 chainId, address contractAddress, uint256 tokenId, address implementation, bytes32 salt) private returns (address proxy) {
        proxy = cloneDeterministic(clone, salt);
        (bool success, bytes memory data) = proxy.call(
            abi.encodeWithSignature("initialize(uint256,address,uint256,address)", chainId, contractAddress, tokenId, implementation)
        );
        require(success, string(data));

        emit AccountCreated(proxy, implementation, chainId, contractAddress, tokenId);
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
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
