const TokenOwnedWalletRegistry = artifacts.require("TokenOwnedWalletRegistry");
const TokenOwnedWalletProxyFactory = artifacts.require("TokenOwnedWalletProxyFactory");

module.exports = function (deployer) {
  deployer.deploy(TokenOwnedWalletProxyFactory).then(() => {
      deployer.link(TokenOwnedWalletProxyFactory, TokenOwnedWalletRegistry);
  });
};
