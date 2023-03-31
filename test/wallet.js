const truffleAssert = require("truffle-assertions");
const {
  encodeERC721SafeTransferFrom,
  encodeERC1155SafeTransferFrom,
  deployProxy,
} = require("./utils");
const TokenOwnedWallet = artifacts.require("TokenOwnedWallet");
const TokenOwnedWalletProxy = artifacts.require("TokenOwnedWalletProxy");
const TokenOwnedWalletRegistry = artifacts.require("TokenOwnedWalletRegistry");
const Migration = artifacts.require("Migration");
const ERC1155 = artifacts.require("@manifoldxyz/creator-core-solidity/MockERC1155");
const ERC721 = artifacts.require("@manifoldxyz/creator-core-solidity/MockERC721");
const CHAIN_ID = 1;

contract("TokenOwnedWallet", function ([owner, newOwner, contractCreator, account1, account2, account3]) {
  let erc721Contract;
  let registry;
  let implementation;
  let contract;

  beforeEach(async () => {
    erc721Contract = await ERC721.new("foo", "FOO", { from: owner });
    await erc721Contract.testMint(owner, 1, { from: owner });
    implementation = await TokenOwnedWallet.new({ from: contractCreator });
    registry = await TokenOwnedWalletRegistry.new(implementation.address, {
      from: contractCreator,
    });
    contract = await deployProxy(CHAIN_ID, registry, erc721Contract.address, 1, contractCreator);
  });

  it("initializes correctly", async () => {
    expect(contract);
  });


  it("can't be initialized twice", async () => {
    const calldata = web3.eth.abi.encodeFunctionCall(
      {
        name: 'initialize',
        type: 'function',
        inputs: [{type: 'uint256', name: 'chainId'}, {type: 'address', name: 'contarctAddress'}, {type: 'uint256', name: 'tokenId'}, {type: 'address', name: '_implementation'}]
      },
      [CHAIN_ID, erc721Contract.address, 1, implementation.address]
    )
    await truffleAssert.reverts(
      web3.eth.call({ to: contract.address, from: contractCreator, data: calldata }),
      "Initializable: contract is already initialized"
    );
  });

  it("uses owner of erc721 token as owner of TokenOwnedWallet", async () => {
    assert.equal(await contract.owner(), owner);
    await erc721Contract.safeTransferFrom(owner, newOwner, 1, { from: owner });
    assert.equal(await contract.owner(), newOwner);
  });

  it("cannot own the token that owns the TokenOwnedWallet", async () => {
    await truffleAssert.reverts(
      erc721Contract.safeTransferFrom(owner, contract.address, 1, { from: owner }),
      "Cannot own yourself"
    );
  });

  it("cannot own the token that is in ownership chain of the TokenOwnedWallet", async () => {
    const erc721Contract1 = await ERC721.new("foo1", "FOO1", { from: owner })
    await erc721Contract1.testMint(account1, 1, { from: owner });
    const tokenOwnedWalletContract1Token1 = await deployProxy(
      CHAIN_ID,
      registry,
      erc721Contract1.address,
      1,
      contractCreator
    );

    const erc721Contract2 = await ERC721.new("foo2", "FOO2", { from: owner });
    await erc721Contract2.testMint(account2, 1, { from: owner });
    const tokenOwnedWalletContract2Token1 = await deployProxy(
      CHAIN_ID,
      registry,
      erc721Contract2.address,
      1,
      contractCreator
    );

    const erc721Contract3 = await ERC721.new("foo3", "FOO3", { from: owner });
    await erc721Contract3.testMint(account3, 1, { from: owner });
    const tokenOwnedWalletContract3Token1 = await deployProxy(
      CHAIN_ID,
      registry,
      erc721Contract3.address,
      1,
      contractCreator
    );

    // Move token that holds erc721Contract1 token 1 to the wallet of erc721Contract2 token 1 (this is ok)
    await erc721Contract1.safeTransferFrom(account1, tokenOwnedWalletContract2Token1.address, 1, { from: account1 });

    // Ensure you can't loop wallet ownership by sending erc721Contract2 token 1 to the wallet of erc721Contract1 token 1,
    // because the wallet of erc721Contract2 token 1 owns erc721Contract1 token 1 and doing so would create a circular loop
    await truffleAssert.reverts(
      erc721Contract2.safeTransferFrom(account2, tokenOwnedWalletContract1Token1.address, 1, { from: account2 }),
      "Token in ownership chain"
    );

    // Attempt to create a 3 token loop
    await erc721Contract2.safeTransferFrom(account2, tokenOwnedWalletContract3Token1.address, 1, { from: account2 });
    // Now: contract2-1's wallet owns contract1-1 token.  contract3-1's wallet owns contract2-1 token.
    // Try to make contract1-1's wallet own contract3-1's token
    await truffleAssert.reverts(
      erc721Contract3.safeTransferFrom(account3, tokenOwnedWalletContract1Token1.address, 1, { from: account3 }),
      "Token in ownership chain"
    );
  });

  it("can own erc721s", async () => {
    const erc721Contract2 = await ERC721.new("foo2", "FOO2", { from: owner });
    await erc721Contract2.testMint(owner, 1, { from: owner });
    await erc721Contract2.safeTransferFrom(owner, contract.address, 1, { from: owner });
    assert.equal(await erc721Contract2.balanceOf(contract.address), 1);
  });

  it("can own erc1155s", async () => {
    const erc1155Contract = await ERC1155.new("");
    await erc1155Contract.testMint(owner, 1, 1, "0x", { from: owner });
    await erc1155Contract.safeTransferFrom(owner, contract.address, 1, 1, "0x", { from: owner });
    assert.equal(await erc1155Contract.balanceOf(contract.address, 1), 1);
  });

  describe("TokenOwnedWallet.execTransaction", () => {
    let erc721Contract2;
    beforeEach(async () => {
      erc721Contract2 = await ERC721.new("foo2", "FOO2", { from: owner });
      await erc721Contract2.testMint(owner, 1, { from: owner });
    });

    it("cannot execute a transaction if not the owner", async () => {
      const encodedSafeTransferFrom = encodeERC721SafeTransferFrom(contract.address, newOwner, 1);
      await truffleAssert.reverts(
        contract.execTransaction(erc721Contract2.address, 0, encodedSafeTransferFrom, 0, {
          from: newOwner,
        }),
        "Caller is not owner"
      );
    });

    it("can transfer an erc721 owned by the TokenOwnedWallet", async () => {
      await erc721Contract2.safeTransferFrom(owner, contract.address, 1, { from: owner });
      assert.equal(await erc721Contract2.balanceOf(contract.address), 1);
      const encodedSafeTransferFrom = encodeERC721SafeTransferFrom(contract.address, newOwner, 1);
      await contract.execTransaction(erc721Contract2.address, 0, encodedSafeTransferFrom, 0, {
        from: owner,
      }),
        assert.equal(await erc721Contract2.balanceOf(newOwner), 1);
    });

    it("can transfer an erc1155 owned by the TokenOwnedWallet", async () => {
      const erc1155Contract = await ERC1155.new("");
      await erc1155Contract.testMint(owner, 1, 1, "0x", { from: owner });
      await erc1155Contract.safeTransferFrom(owner, contract.address, 1, 1, "0x", { from: owner });
      assert.equal(await erc1155Contract.balanceOf(contract.address, 1), 1);
      const encodedSafeTransferFrom = encodeERC1155SafeTransferFrom(
        contract.address,
        newOwner,
        1,
        1
      );
      await contract.execTransaction(erc1155Contract.address, 0, encodedSafeTransferFrom, 0, {
        from: owner,
      });
      assert.equal(await erc1155Contract.balanceOf(newOwner, 1), 1);
    });

    it("can upgrade wallet implementation", async () => {
      const newImplementation = await TokenOwnedWallet.new({ from: contractCreator });
      const migration = await Migration.new(newImplementation.address, { from: contractCreator });
      const encodedUpgrade = web3.eth.abi.encodeFunctionCall(
        {
          inputs: [],
          name: "migrate",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        []
      );
      truffleAssert.passes(
        contract.execTransaction(migration.address, 0, encodedUpgrade, 1, {
          from: owner,
        })
      );
      const proxy = await TokenOwnedWalletProxy.at(contract.address);
      assert.equal(await proxy.implementation(), newImplementation.address);
    });
  });
});
