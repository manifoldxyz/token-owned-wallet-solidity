// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./ITokenOwnedWallet.sol";
import "./lib/TokenOwnedWalletBytecode.sol";

/**
 * @title TokenWallet
 * @notice A lightweight smart contract wallet linked to an ERC721 token.
 */
contract TokenOwnedWallet {
    // Padding for initializable values
    uint256 private _initializablePadding;

    event TransactionExecuted(address indexed target, uint256 indexed value, bytes data);

    function owner() public view returns (address) {
        (uint256 chainId, address contractAddress, uint256 tokenId) = TokenOwnedWalletBytecode
            .token();
        if (chainId != block.chainid) return address(0);
        return IERC721(contractAddress).ownerOf(tokenId);
    }

    function execTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) public returns (bytes memory _result) {
        require(owner() == msg.sender, "Caller is not owner");
        bool success;
        // solhint-disable-next-line avoid-low-level-calls
        (success, _result) = _target.call{value: _value}(_data);
        require(success, string(_result));
        emit TransactionExecuted(_target, _value, _data);
        return _result;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return (interfaceId == type(ITokenOwnedWallet).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }

    function onERC721Received(
        address,
        address,
        uint256 receivedTokenId,
        bytes memory
    ) public virtual returns (bytes4) {
        (uint256 _chainId, address _contractAddress, uint256 _tokenId) = TokenOwnedWalletBytecode
            .token();
        require(
            _chainId != block.chainid ||
                msg.sender != _contractAddress ||
                receivedTokenId != _tokenId,
            "Cannot own yourself"
        );
        _revertIfOwnershipCycle(msg.sender, receivedTokenId);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Helper method to check if a received token is in the ownership chain of the wallet.
     * @param receivedTokenAddress The address of the token being received.
     * @param receivedTokenId The ID of the token being received.
     */
    function _revertIfOwnershipCycle(address receivedTokenAddress, uint256 receivedTokenId)
        internal
        view
    {
        address currentOwner = owner();
        require(currentOwner != address(this), "Token in ownership chain");

        uint32 currentOwnerSize;
        /// @solidity memory-safe-assembly
        assembly {
            currentOwnerSize := extcodesize(currentOwner)
        }
        while (currentOwnerSize > 0) {
            try ITokenOwnedWallet(currentOwner).token() returns (
                uint256 chainId,
                address contractAddress,
                uint256 tokenId
            ) {
                require(
                    chainId != block.chainid ||
                        contractAddress != receivedTokenAddress ||
                        tokenId != receivedTokenId,
                    "Token in ownership chain"
                );
                // Advance up the ownership chain
                currentOwner = IERC721(contractAddress).ownerOf(tokenId);
                require(currentOwner != address(this), "Token in ownership chain");
                /// @solidity memory-safe-assembly
                assembly {
                    currentOwnerSize := extcodesize(currentOwner)
                }
            } catch {
                break;
            }
        }
    }
}
