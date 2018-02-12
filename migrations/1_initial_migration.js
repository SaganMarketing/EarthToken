var Migrations = artifacts.require("../contracts/Migrations.sol");
var EarthToken = artifacts.require("../contracts/EarthToken.sol");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(EarthToken);
};
