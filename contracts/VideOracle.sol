// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

contract VideOracle {

    uint256 constant TOTAL_VOTES = 5;

    enum RequestStatus { ACTIVE, VOTING, CLOSED }
    struct Request {
        uint256 endTime;
        uint256 reward;
        RequestStatus status;
        address requester;
        string requestUri;
    }

    mapping(uint256 => Request) public requests;
    uint256 public requestsCount;

    struct Proof {
        uint256 tokenId;
        address payable verifier;
    }

    mapping(uint256 => mapping(uint256 => Proof)) public proofsByRequest;
    mapping(uint256 => uint256) public proofsCount4Request;
    mapping(uint256 => mapping(uint256 => uint256)) public pointsForProof4Request;
    mapping(uint256 => mapping(uint256 => bool)) public claimedProof4Request;

    event NewRequest(address indexed src, uint256 requestId, uint256 timeToProof, uint256 reward,  string requestUri);
    event NewProof(address indexed src, uint256 indexed requestId, uint256 proofId);

    function createRequest(uint256 time2proof, uint256 reward, string calldata requestURI) public payable returns(uint256 requestId) {
        require(msg.value >= reward, 'value sent not enough');

        requestId = requestsCount++;
        requests[requestId] = Request({
            endTime: block.timestamp + time2proof,
            reward: reward,
            status: RequestStatus.ACTIVE,
            requester: msg.sender,
            requestUri: requestURI
        });

        if (msg.value > reward) {
            Address.sendValue(payable(msg.sender),  msg.value - reward);
        }

        emit NewRequest(msg.sender, requestId, time2proof, reward, requestURI);
    }

    function submitProof(uint256 requestId, uint256 tokenId) public returns(uint256 proofId) {
        require(requestId < requestsCount, 'request does not exist');

        Request memory request = requests[requestId];

        require(request.requester != msg.sender, 'you cannot proof your own request');

        require(request.status == RequestStatus.ACTIVE, 'request not in active state');

        proofId = proofsCount4Request[requestId]++;

        proofsByRequest[requestId][proofId] = Proof({
            tokenId: tokenId,
            verifier: payable(msg.sender)
        });

        emit NewProof(msg.sender, requestId, proofId);
    }

    function voteProofs(uint256 requestId, uint256[] calldata proofsIds, uint256[] calldata points) public {
        require(proofsIds.length == points.length, 'check proofsIds and points');

        Request storage request = requests[requestId];

        require(request.requester == msg.sender, 'only proofer can vote their own requests');

        if (request.status == RequestStatus.ACTIVE && request.endTime >= block.timestamp) {
            request.status = RequestStatus.VOTING;
        }

        require(request.status == RequestStatus.VOTING, 'request not in voting state');

        uint256 totalVotes = 0;
        for(uint256 i = 0; i < proofsIds.length; i++) {
            uint256 proofPoints = points[i];
            totalVotes += proofPoints;
            pointsForProof4Request[requestId][proofsIds[i]] = proofPoints;
        }

        require(totalVotes <= TOTAL_VOTES, 'too many votes');

        request.status = RequestStatus.CLOSED;
    }

    function claim(uint256 requestId, uint256 proofId) public {
        uint256 points = pointsForProof4Request[requestId][proofId];
        require(points > 0, 'no points to your request');

        require(claimedProof4Request[requestId][proofId] == false, 'already claimed');

        claimedProof4Request[requestId][proofId] = true;

        uint256 proofReward = requests[requestId].reward * points / TOTAL_VOTES;

        Address.sendValue(
            (proofsByRequest[requestId][proofId]).verifier,
            proofReward
        );
    }
}
