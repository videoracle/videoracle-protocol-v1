import hre, { ethers } from "hardhat";
import { get, ConfigProperty } from "../../utils/configManager";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const [, , bob] = await ethers.getSigners();

  // Get contracts
  const videOracle = await ethers.getContractAt(
    "VideOracle",
    get(network, ConfigProperty.VideOracle)
  );

  // Submit proof
  const requestId = 0;
  const proofUri = "QmYekSW5qDKZEehxGoQo8cw5JoiY1eHoEkNvTrSK2C7j3r";

  const tx = await videOracle.connect(bob).submitProof(requestId, proofUri);
  const receipt = await tx.wait();

  const proofId = receipt.events
    ?.find((e: any) => e.event === "NewProof")
    ?.args?.proofId.toString();

  console.log(
    "Submitted proof with id:",
    proofId,
    ", for request with id:",
    requestId
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
