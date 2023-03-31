// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenOwnedWalletProxy is Initializable {

    uint256 private _chainId;
    address private _contractAddress;
    uint256 private _tokenId;
    uint256 private _nonce;

    constructor() {
        assert(
            _IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
    }

    /**
     * Initializer
     */
    function initialize(uint256 chainId, address contractAddress, uint256 tokenId, address implementation_) public initializer {
        require(implementation_ != address(0), "Invalid implementation address");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = implementation_;
        if (chainId != block.chainid) {
            _chainId = chainId;
        }
        _contractAddress = contractAddress;
        _tokenId = tokenId;
    }

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view returns (address) {
        return _implementation();
    }

    function _implementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation_) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function upgrade(address implementation_) public {
        require(msg.sender == _owner(), "Caller is not owner");
        require(implementation_ != address(0), "Invalid implementation address");
        ++_nonce;
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = implementation_;
    }

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        ++_nonce;
        _delegate(_implementation());
    }

    /**
     * @dev Returns the owner token chainId, contract address, and token id.
     */
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId) {
        if (_chainId == 0) {
            return (block.chainid, _contractAddress, _tokenId);
        }
        return (_chainId, _contractAddress, _tokenId);
    }

    /**
     * @dev Returns the owner of the token owned wallet
     */
    function owner() external view returns (address) {
        return _owner();
    }

    function _owner() private view returns (address) {
        return IERC721(_contractAddress).ownerOf(_tokenId);
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

}
