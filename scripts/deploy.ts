import hre, { ethers } from "hardhat";
import { ConfigProperty, set } from "../utils/configManager";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const VideOracle = await ethers.getContractFactory("VideOracle");
  const videOracle = await VideOracle.deploy();

  console.log("Deployed VideOracle at", videOracle.address);
  set(network, ConfigProperty.VideOracle, videOracle.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
