const truffleAssert = require("truffle-assertions");
const { encodeERC721SafeTransferFrom } = require("./utils");
const TokenOwnedWallet = artifacts.require("TokenOwnedWallet");
const TokenOwnedWalletProxy = artifacts.require("TokenOwnedWalletProxy");
const TokenOwnedWalletRegistry = artifacts.require("TokenOwnedWalletRegistry");
const ERC721 = artifacts.require("@manifoldxyz/creator-core-solidity/MockERC721");
const CHAIN_ID = 1;

contract("TokenOwnedWalletRegistry", function ([owner, newOwner]) {
  let erc721Contract;
  let proxy;
  let implementation;
  let registry;
  let initbytedata;

  beforeEach(async function () {
    erc721Contract = await ERC721.new("foo", "FOO", { from: owner });
    await erc721Contract.testMint(owner, 1, { from: owner });
    proxy = await TokenOwnedWalletProxy.new();
    implementation = await TokenOwnedWallet.new();
    registry = await TokenOwnedWalletRegistry.new();
    initbytedata = web3.eth.abi.encodeFunctionCall(
      {
        name: "initialize",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "implementation_",
          },
        ],
      },
      [implementation.address]
    );
  });

  describe("TokenOwnedWalletRegistry.create", function () {
    let erc721Contract2;
    beforeEach(async () => {
      erc721Contract2 = await ERC721.new("foo2", "FOO2", { from: owner });
      await erc721Contract2.testMint(owner, 1, { from: owner });
    });

    it("Creates tokenOwnedWallet", async function () {
      const expectedAddress = await registry.addressOf(
        proxy.address,
        CHAIN_ID,
        erc721Contract.address,
        1,
        1
      );

      await registry.create(proxy.address, CHAIN_ID, erc721Contract.address, 1, 1, initbytedata, {
        from: owner,
      });
      // Can't be deployed twice
      await truffleAssert.reverts(
        registry.create(proxy.address, CHAIN_ID, erc721Contract.address, 1, 1, initbytedata),
        "Create2: Failed on deploy."
      );

      const tokenOwnedWalletAddress = await registry.addressOf(
        proxy.address,
        CHAIN_ID,
        erc721Contract.address,
        1,
        1
      );
      assert.equal(tokenOwnedWalletAddress, expectedAddress);

      const tokenOwnedWalletContract = await TokenOwnedWalletProxy.at(tokenOwnedWalletAddress);
      const expectedOwner = await erc721Contract.ownerOf(1);

      assert.equal(await tokenOwnedWalletContract.owner(), expectedOwner);

      const token = await tokenOwnedWalletContract.token();
      assert.equal(token[0], CHAIN_ID);
      assert.equal(token[1], erc721Contract.address);
      assert.equal(token[2], 1);

      assert.equal(await tokenOwnedWalletContract.implementation(), implementation.address);
    });

    it("Creates functional tokenOwnedWallet", async function () {
      const tokenOwnedWalletAddress = (
        await registry.create(proxy.address, CHAIN_ID, erc721Contract.address, 1, 1, initbytedata, {
          from: owner,
        })
      ).logs[0].args.account;
      const tokenOwnedWalletContract = await TokenOwnedWallet.at(tokenOwnedWalletAddress);

      await erc721Contract2.safeTransferFrom(owner, tokenOwnedWalletAddress, 1, { from: owner });

      const encodedSafeTransferFrom = encodeERC721SafeTransferFrom(
        tokenOwnedWalletAddress,
        newOwner,
        1
      );
      await truffleAssert.passes(
        tokenOwnedWalletContract.execTransaction(
          erc721Contract2.address,
          0,
          encodedSafeTransferFrom,
          {
            from: owner,
          }
        )
      );

      assert.equal(await erc721Contract2.balanceOf(newOwner), 1);
    });
  });
});
