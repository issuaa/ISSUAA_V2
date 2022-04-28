var fs = require('fs');
const vestingEntries = JSON.parse(fs.readFileSync('../vestingSchedule.json', 'utf8'));

const Migrations = artifacts.require("Migrations");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};
