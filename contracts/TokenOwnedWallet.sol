// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./ITokenOwnedWallet.sol";

/**
 * @title TokenWallet
 * @notice A lightweight smart contract wallet linked to an ERC721 token.
 */
contract TokenOwnedWallet is ITokenOwnedWallet {
    using Strings for uint256;
    using Strings for uint16;

    event TransactionExecuted(address indexed target, uint256 indexed value, bytes data);

    // The ERC721 token linked to the wallet instance
    Token private _token;

    /**
     * @dev Throws if the sender is not the backpack owner.
     */
    modifier onlyOwner() {
        require(_isOwner(msg.sender), "Caller is not owner");
        _;
    }

    /**
     * Initializer
     */
    function initialize(address contractAddress, uint256 tokenId) public {
        require(
            ERC165Checker.supportsInterface(contractAddress, type(IERC721).interfaceId),
            "Owning contract must be ERC721"
        );
        require(_token.contractAddress == address(0) && _token.id == 0, "Already initialized");
        _token.contractAddress = contractAddress;
        _token.id = tokenId;
    }

    /**
     * @inheritdoc ITokenOwnedWallet
     */
    function token() public view override returns (Token memory) {
        return _token;
    }

    /**
     * @inheritdoc ITokenOwnedWallet
     */
    function owner() public view override returns (address) {
        return IERC721(_token.contractAddress).ownerOf(_token.id);
    }

    /**
     * @inheritdoc ITokenOwnedWallet
     */
    function execTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data,
        Operation _operation
    ) public override onlyOwner returns (bytes memory _result) {
        bool success;
        if (_operation == Operation.DelegateCall) {
            // solhint-disable-next-line avoid-low-level-calls
            (success, _result) = _target.delegatecall(_data);
        } else {
            // solhint-disable-next-line avoid-low-level-calls
            (success, _result) = _target.call{value: _value}(_data);
        }
        require(success, "TokenWallet: transaction failed");
        emit TransactionExecuted(_target, _value, _data);
        return _result;
    }

    /**
     * @inheritdoc ITokenOwnedWallet
     */
    function getChainId() public view override returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165)
        returns (bool)
    {
        return (interfaceId == type(ITokenOwnedWallet).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }

    /**
     * @inheritdoc IERC721Receiver
     */
    function onERC721Received(
        address,
        address,
        uint256 receivedTokenId,
        bytes memory
    ) public virtual override returns (bytes4) {
        _revertIfOwnershipCycle(msg.sender, receivedTokenId);
        return this.onERC721Received.selector;
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Helper method to check if an address is the owner of the token.
     * @param _addr The address.
     */
    function _isOwner(address _addr) internal view returns (bool) {
        return owner() == _addr;
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

        // Iterate through this wallet's ownership chain
        while (ERC165Checker.supportsInterface(currentOwner, type(ITokenOwnedWallet).interfaceId)) {
            Token memory currentToken = ITokenOwnedWallet(currentOwner).token();

            require(
                !(currentToken.contractAddress == receivedTokenAddress &&
                    currentToken.id == receivedTokenId),
                "Token in ownership chain"
            );

            // Advance up the ownership chain
            currentOwner = IERC721(currentToken.contractAddress).ownerOf(currentToken.id);
        }
    }
}
