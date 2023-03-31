const truffleAssert = require("truffle-assertions");
const { encodeERC721SafeTransferFrom } = require("./utils");
const TokenOwnedWallet = artifacts.require("TokenOwnedWallet");
const TokenOwnedWalletProxy = artifacts.require("TokenOwnedWalletProxy");
const TokenOwnedWalletRegistry = artifacts.require("TokenOwnedWalletRegistry");
const ERC721 = artifacts.require("@manifoldxyz/creator-core-solidity/MockERC721");
const CHAIN_ID = 1;

contract("TokenOwnedWalletRegistry", function ([owner, newOwner, contractCreator]) {
  let erc721Contract;
  let proxy;
  let implementation;
  let registry;

  beforeEach(async function () {
    erc721Contract = await ERC721.new("foo", "FOO", { from: owner });
    await erc721Contract.testMint(owner, 1, { from: owner });
    proxy = await TokenOwnedWalletProxy.new();
    implementation = await TokenOwnedWallet.new();
    registry = await TokenOwnedWalletRegistry.new(proxy.address, implementation.address, {
      from: contractCreator,
    });
  });

  describe("TokenOwnedWalletRegistry.create", function () {
    let erc721Contract2;
    beforeEach(async () => {
      erc721Contract2 = await ERC721.new("foo2", "FOO2", { from: owner });
      await erc721Contract2.testMint(owner, 1, { from: owner });
    });

    it("Creates tokenOwnedWallet", async function () {
      await registry.create(CHAIN_ID, erc721Contract.address, 1, { from: owner });
      const tokenOwnedWalletAddress = await registry.addressOf(CHAIN_ID, erc721Contract.address, 1);
      const tokenOwnedWalletContract = await TokenOwnedWallet.at(tokenOwnedWalletAddress);
      const expectedOwner = await erc721Contract.ownerOf(1);

      assert.equal(await tokenOwnedWalletContract.owner(), expectedOwner);
    });

    it("Create returns current tokenOwnedWallet address", async function () {
      await registry.create(CHAIN_ID, erc721Contract.address, 1, { from: owner });
      const firstCreateAddress = await registry.addressOf(CHAIN_ID, erc721Contract.address, 1);
      await registry.create(CHAIN_ID, erc721Contract.address, 1, { from: owner });
      const secondCreateAddress = await registry.addressOf(CHAIN_ID, erc721Contract.address, 1);

      assert.equal(firstCreateAddress, secondCreateAddress);
    });

    it("Creates functional tokenOwnedWallet", async function () {
      await registry.create(CHAIN_ID, erc721Contract.address, 1, { from: owner });
      const tokenOwnedWalletAddress = await registry.addressOf(CHAIN_ID, erc721Contract.address, 1);
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

  describe("TokenOwnedWalletRegistry.addressOf", function () {
    it("Address recorded", async function () {
      await registry.create(CHAIN_ID, erc721Contract.address, 1, { from: owner });
      const tokenOwnedWalletAddress = await registry.addressOf(CHAIN_ID, erc721Contract.address, 1);

      assert.notEqual(tokenOwnedWalletAddress, "0x0000000000000000000000000000000000000000");
    });

    it("Null address if not created", async function () {
      const tokenOwnedWalletAddress = await registry.addressOf(CHAIN_ID, erc721Contract.address, 1);

      assert.equal(tokenOwnedWalletAddress, "0x0000000000000000000000000000000000000000");
    });
  });

  describe("TokenOwnedWalletRegistry.addressExists", function () {
    it("Address exists", async function () {
      await registry.create(CHAIN_ID, erc721Contract.address, 1, { from: owner });
      const exists = await registry.addressExists(CHAIN_ID, erc721Contract.address, 1);

      assert(exists);
    });

    it("Address does not exist", async function () {
      const exists = await registry.addressExists(CHAIN_ID, erc721Contract.address, 1);

      assert(!exists);
    });
  });
});
