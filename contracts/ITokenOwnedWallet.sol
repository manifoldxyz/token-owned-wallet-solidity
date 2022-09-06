// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ITokenOwnedWallet
 * @notice Interface for a smart contract wallet linked to an ERC721 token.
 */
interface ITokenOwnedWallet is IERC165, IERC721Receiver, IERC1155Receiver {
    struct Token {
        address contractAddress;
        uint256 id;
    }

    /**
     * @notice Executes a generic transaction.
     * @param target The address for the transaction.
     * @param value The value of the transaction.
     * @param data The data of the transaction.
     */
    function execTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory);

    /**
     * @notice Returns the token linked to the wallet instance.
     * @return Token - The ERC721 token.
     */
    function token() external view returns (Token memory);

    /**
     * @notice Returns the owner of the token linked to the wallet instance.
     * @return address - The wallet address.
     */
    function owner() external view returns (address);

    /**
     * @notice Returns the chain ID that the token wallet is deployed on.
     * @return uint256 - The chain ID.
     */
    function getChainId() external view returns (uint256);
}
