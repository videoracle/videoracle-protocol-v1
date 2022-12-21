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

  // Vote proofs
  const requestId = 0;
  const proofIds = [0, 1, 2];
  const points = [2, 2, 1];

  const tx = await videOracle
    .connect(alice)
    .voteProofs(requestId, proofIds, points);
  await tx.wait();

  console.log(
    "Votes proofs with ids: ",
    proofIds,
    ", with points: ",
    points,
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
