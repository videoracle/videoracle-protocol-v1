import hre, { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import { get, ConfigProperty } from "../../utils/configManager";
import uploadToIPFS from "../../utils/ipfs";
import { VideOracle } from "../../typechain-types";

async function main() {
  const network = hre.network.name;
  console.log("Network:", network);

  const [, alice, bob, carol, david, eve] = await ethers.getSigners();

  // Get contracts
  const videOracle = (await ethers.getContractAt(
    "VideOracle",
    get(network, ConfigProperty.VideOracle)
  )) as VideOracle;

  // Create requests
  const requests = [
    {
      requester: alice,
      timeToAnswer: 1,
      reward: ethers.utils.parseEther("1"),
      metadata: {
        title: "This is a request to make something",
        description:
          "Lorem ipsum dolor sit amet consectetur adipisicing elit. Velit a officiis explicabo sequi doloribus assumenda, dicta vel, reiciendis consequuntur deserunt quos hic quae soluta eligendi et harum magni. Corrupti, voluptatum.",
        image: "https://i.imgur.com/hMVpght.jpeg",
        location: {
          address: "Milan, Italy",
          lat: 40.7128,
          lng: 74.006,
        },
      },
    },
    {
      requester: bob,
      timeToAnswer: 1,
      reward: ethers.utils.parseEther("1"),
      metadata: {
        title: "This is a request to make something",
        description:
          "Lorem ipsum dolor sit amet consectetur adipisicing elit. Velit a officiis explicabo sequi doloribus assumenda, dicta vel, reiciendis consequuntur deserunt quos hic quae soluta eligendi et harum magni. Corrupti, voluptatum.",
        image: "https://i.imgur.com/hMVpght.jpeg",
        location: {
          address: "Milan, Italy",
          lat: 40.7128,
          lng: 74.006,
        },
      },
    },
    {
      requester: carol,
      timeToAnswer: 3600,
      reward: ethers.utils.parseEther("1"),
      metadata: {
        title: "This is a request to make something",
        description:
          "Lorem ipsum dolor sit amet consectetur adipisicing elit. Velit a officiis explicabo sequi doloribus assumenda, dicta vel, reiciendis consequuntur deserunt quos hic quae soluta eligendi et harum magni. Corrupti, voluptatum.",
        image: "https://i.imgur.com/hMVpght.jpeg",
        location: {
          address: "Milan, Italy",
          lat: 40.7128,
          lng: 74.006,
        },
      },
    },
  ];

  for (const request of requests) {
    const { timeToAnswer, reward, metadata, requester } = request;

    const requestUri = await uploadToIPFS(metadata);
    if (!requestUri) return;

    const fee = reward.div(100).mul(30);

    const createRequestTx = await videOracle
      .connect(requester)
      .createRequest(timeToAnswer, reward, requestUri, {
        value: reward.add(fee),
      });
    const receipt = await createRequestTx.wait();

    const requestId = receipt.events
      ?.find((e: any) => e.event === "NewRequest")
      ?.args?.requestId.toString();

    console.log("Created request with id:", requestId);
  }

  // Submit proofs
  const proofUri =
    "bafkreibrcwvsrtujst2shg7qhi6kkmeomwnbhibjadp2m4btyhbfoi3dl4";
  const proofLat = 387241060;
  const proofLng = -91345574;
  const proofs = [
    {
      verifier: bob,
      requestId: 0,
      proofUri,
      latitude: proofLat,
      longitude: proofLng,
    },
    {
      verifier: carol,
      requestId: 0,
      proofUri,
      latitude: proofLat,
      longitude: proofLng,
    },
    {
      verifier: david,
      requestId: 1,
      proofUri,
      latitude: proofLat,
      longitude: proofLng,
    },
    {
      verifier: eve,
      requestId: 1,
      proofUri,
      latitude: proofLat,
      longitude: proofLng,
    },
  ];

  for (const proof of proofs) {
    const { requestId, proofUri, verifier, latitude, longitude } = proof;

    const submitProofTx = await videOracle
      .connect(verifier)
      .submitProof(requestId, proofUri, latitude, longitude);
    const receipt = await submitProofTx.wait();

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

  // Vote on proofs
  time.increase(requests[0].timeToAnswer);

  const requestId = 0;
  const proofIds = [0, 1, 2];
  const points = [2, 2, 1];

  const tx = await videOracle
    .connect(alice)
    .voteProofs(requestId, proofIds, points);
  await tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
