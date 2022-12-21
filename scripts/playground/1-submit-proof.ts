import hre, { ethers } from "hardhat";
import { get, ConfigProperty } from "../../utils/configManager";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const [, , bob] = await ethers.getSigners();

  const requestId = 0;
  const livePeerTokenId = 0; // TODO: use actual livepeer video

  // Get contracts
  const videOracle = await ethers.getContractAt(
    "VideOracle",
    get(network, ConfigProperty.VideOracle)
  );

  // Submit proof
  const tx = await videOracle
    .connect(bob)
    .submitProof(requestId, livePeerTokenId);
  const receipt = await tx.wait();

  const proofId = receipt.events
    ?.find((e) => e.event === "NewProof")
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
