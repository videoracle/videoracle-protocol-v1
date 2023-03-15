// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract VideOracle is Ownable2Step {
    enum RequestStatus {
        ACTIVE,
        VOTING,
        CLOSED
    }
    struct Request {
        uint256 endTime;
        uint256 reward;
        RequestStatus status;
        address requester;
        string requestUri;
    }
    struct Proof {
        address payable verifier;
        string proofUri;
        // lat/long in 1e7
        int256 latitude;
        int256 longitude;
    }

    event NewRequest(
        address indexed src,
        uint256 requestId,
        uint256 endTime,
        uint256 reward,
        string requestUri
    );
    event NewProof(
        address indexed src,
        uint256 indexed requestId,
        uint256 proofId,
        string proofUri,
        int256 latitude,
        int256 longitude
    );
    event RequestVotingOpened(address indexed src, uint256 indexed requestId);
    event RequestClosed(address indexed src, uint256 indexed requestId);

    uint256 constant TOTAL_VOTES = 5;
    uint256 private _feeBPS = 30000; // 100% = 100000
    address private _feeCollector;

    mapping(uint256 => Request) public requests;
    uint256 public requestsCount;
    mapping(uint256 => mapping(uint256 => Proof)) public proofsByRequest;
    mapping(uint256 => uint256) public proofsCount4Request;
    mapping(uint256 => mapping(uint256 => uint256))
        public pointsForProof4Request;
    mapping(uint256 => mapping(uint256 => bool)) public claimedProof4Request;

    constructor(address feeCollector_) {
        _feeCollector = feeCollector_;
    }

    function updateFeeBPS(uint256 fee_) public onlyOwner {
        _feeBPS = fee_;
    }

    function updateFeeCollector(address collector_) public onlyOwner {
        _feeCollector = collector_;
    }

    function createRequest(
        uint256 time2proof, uint256 reward, string calldata requestUri
    ) public payable returns (uint256 requestId) {
        uint256 minIn = (reward * (1e5 + _feeBPS)) / 1e5;
        require(msg.value >= minIn, "value sent not enough");

        requestId = requestsCount++;
        uint256 endTime = block.timestamp + time2proof;
        requests[requestId] = Request({
            endTime: endTime,
            reward: reward,
            status: RequestStatus.ACTIVE,
            requester: msg.sender,
            requestUri: requestUri
        });

        // Send fee to collector
        Address.sendValue(payable(_feeCollector), (reward * _feeBPS) / 1e5);
        if (msg.value > minIn) {
            Address.sendValue(payable(msg.sender), msg.value - minIn);
        }

        emit NewRequest(msg.sender, requestId, endTime, reward, requestUri);
    }

    function submitProof(uint256 requestId, string calldata proofUri, int256 latitude, int256 longitude)
        public
        returns (uint256 proofId)
    {
        require(requestId < requestsCount, "request does not exist");

        Request memory request = requests[requestId];

        require(
            request.requester != msg.sender,
            "you cannot proof your own request"
        );

        require(
            request.status == RequestStatus.ACTIVE,
            "request not in active state"
        );

        proofId = proofsCount4Request[requestId]++;

        proofsByRequest[requestId][proofId] = Proof({
            proofUri: proofUri,
            verifier: payable(msg.sender),
            latitude: latitude,
            longitude: longitude
        });

        emit NewProof(msg.sender, requestId, proofId, proofUri, latitude, longitude);
    }

    function voteProofs(
        uint256 requestId,
        uint256[] calldata proofsIds,
        uint256[] calldata points
    ) public {
        require(
            proofsIds.length == points.length,
            "check proofsIds and points"
        );

        Request storage request = requests[requestId];

        require(
            request.requester == msg.sender,
            "only proofer can vote their own requests"
        );

        if (
            request.status == RequestStatus.ACTIVE &&
            request.endTime <= block.timestamp
        ) {
            request.status = RequestStatus.VOTING;
            emit RequestVotingOpened(request.requester, requestId);
        }

        require(
            request.status == RequestStatus.VOTING,
            "request not in voting state"
        );

        uint256 totalVotes = 0;
        for (uint256 i = 0; i < proofsIds.length; i++) {
            uint256 proofPoints = points[i];
            totalVotes += proofPoints;
            pointsForProof4Request[requestId][proofsIds[i]] = proofPoints;
        }

        require(totalVotes <= TOTAL_VOTES, "too many votes");

        request.status = RequestStatus.CLOSED;
        emit RequestClosed(request.requester, requestId);
    }

    function claim(uint256 requestId, uint256 proofId) public {
        uint256 points = pointsForProof4Request[requestId][proofId];
        require(points > 0, "no points to your request");

        require(
            claimedProof4Request[requestId][proofId] == false,
            "already claimed"
        );

        claimedProof4Request[requestId][proofId] = true;

        uint256 proofReward = (requests[requestId].reward * points) /
            TOTAL_VOTES;

        Address.sendValue(
            (proofsByRequest[requestId][proofId]).verifier,
            proofReward
        );
    }

    function closeRequest(uint256 requestId) public {
        Request storage request = requests[requestId];

        require(
            request.requester == msg.sender,
            "only proofer can close their own requests"
        );

        require(
            request.endTime <= block.timestamp,
            "request not expired yet"
        );

        request.status = RequestStatus.CLOSED;
        emit RequestClosed(request.requester, requestId);

        Address.sendValue(payable(request.requester), request.reward);
    }
}
