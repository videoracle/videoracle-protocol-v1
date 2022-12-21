import hre, { ethers } from "hardhat";
import { ConfigProperty, set } from "../utils/configManager";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const [deployer, ...users] = await ethers.getSigners();

  const SimpleERC20 = await ethers.getContractFactory("SimpleERC20");
  const userAddresses = users.splice(0, 5).map((signer) => signer.address);
  const simpleERC20 = await SimpleERC20.deploy([
    deployer.address,
    ...userAddresses,
  ]);

  console.log("Deployed SimpleERC20 at", simpleERC20.address);
  set(network, ConfigProperty.SimpleERC20, simpleERC20.address);

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
