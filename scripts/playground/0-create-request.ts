import hre, { ethers } from "hardhat";
import { get, ConfigProperty } from "../../utils/configManager";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const [, alice] = await ethers.getSigners();

  // Get contracts
  const videOracle = await ethers.getContractAt(
    "VideOracle",
    get(network, ConfigProperty.VideOracle)
  );

  // Create request
  const requestUri = "request-uri";
  const timeToAnswer = 100;
  const reward = 100;

  const createRequestTx = await videOracle
    .connect(alice)
    .createRequest(timeToAnswer, reward, requestUri, {
      value: reward,
    });
  const receipt = await createRequestTx.wait();

  const requestId = receipt.events
    ?.find((e) => e.event === "NewRequest")
    ?.args?.requestId.toString();

  console.log("Created request with id:", requestId);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
