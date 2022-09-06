const encodeERC721SafeTransferFrom = (fromAddress, toAddress, tokenId) => {
  return web3.eth.abi.encodeFunctionCall(
    {
      inputs: [
        {
          internalType: "address",
          name: "from",
          type: "address",
        },
        {
          internalType: "address",
          name: "to",
          type: "address",
        },
        {
          internalType: "uint256",
          name: "tokenId",
          type: "uint256",
        },
      ],
      name: "safeTransferFrom",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
    [fromAddress, toAddress, tokenId]
  );
};

const encodeERC1155SafeTransferFrom = (fromAddress, toAddress, tokenId, amount) => {
  return web3.eth.abi.encodeFunctionCall(
    {
      inputs: [
        {
          internalType: "address",
          name: "from",
          type: "address",
        },
        {
          internalType: "address",
          name: "to",
          type: "address",
        },
        {
          internalType: "uint256",
          name: "id",
          type: "uint256",
        },
        {
          internalType: "uint256",
          name: "amount",
          type: "uint256",
        },
        {
          internalType: "bytes",
          name: "data",
          type: "bytes",
        },
      ],
      name: "safeTransferFrom",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
    [fromAddress, toAddress, tokenId, amount, "0x"]
  );
};

module.exports = { encodeERC721SafeTransferFrom, encodeERC1155SafeTransferFrom };
