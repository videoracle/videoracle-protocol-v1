import hre, { ethers } from "hardhat";
import { ConfigProperty, set } from "../utils/configManager";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const VideOracle = await ethers.getContractFactory("VideOracle");
  const videOracle = await VideOracle.deploy("0x8B98AF5d06C9d34042f93B1c0889F1E95170B0fE");

  console.log("Deployed VideOracle at", videOracle.address);
  set(network, ConfigProperty.VideOracle, videOracle.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
