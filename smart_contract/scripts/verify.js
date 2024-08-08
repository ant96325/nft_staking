const hre = require("hardhat");
const fs = require('fs');
const fse = require("fs-extra");
const { verify } = require('../utils/verify')
const { getAmountInWei, developmentChains } = require('../utils/helper-scripts');
const {stakingContractAddress, nftContractAddress, tokenContractAddress} = require('../utils/contracts-config')

async function main() {
    const deployNetwork = hre.network.name
    if (!developmentChains.includes(deployNetwork) && hre.config.etherscan.apiKey[deployNetwork]) {
      console.log("waiting for 6 blocks verification ...")
      await stakingVault.deployTransaction.wait(6)
  
      // args represent contract constructor arguments
      const args = [nftContractAddress, tokenContractAddress]
      await verify(stakingContractAddress, args)
    }
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
