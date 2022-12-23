import hre, { ethers } from "hardhat";
import { get, ConfigProperty } from "../../utils/configManager";
import uploadToIPFS from "../../utils/ipfs";

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
  const timeToAnswer = 100;
  const reward = 100;

  const requestUri = await uploadToIPFS({
    title: "This is a request to make something",
    description:
      "Lorem ipsum dolor sit amet consectetur adipisicing elit. Velit a officiis explicabo sequi doloribus assumenda, dicta vel, reiciendis consequuntur deserunt quos hic quae soluta eligendi et harum magni. Corrupti, voluptatum.",
    image: "https://i.imgur.com/hMVpght.jpeg",
    location: "40.7128,-74.0060",
  });
  if (!requestUri) return;

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
