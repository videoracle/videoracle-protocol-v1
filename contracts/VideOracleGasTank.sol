// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {GasTank} from "./GasTank.sol";

contract VideOracle is Ownable2Step, GasTank {
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
        uint256 tokenId;
        address payable verifier;
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
        uint256 tokenId
    );
    event RequestVotingOpened(address indexed src, uint256 indexed requestId);
    event RequestClosed(address indexed src, uint256 indexed requestId);

    uint256 constant TOTAL_VOTES = 5;
    uint256 private _feeBPS = 300; // 100% = 10000
    address private _feeCollector;
    IERC721 public videoNFT;

    mapping(uint256 => Request) public requests;
    uint256 public requestsCount;
    mapping(uint256 => mapping(uint256 => Proof)) public proofsByRequest;
    mapping(uint256 => uint256) public proofsCount4Request;
    mapping(uint256 => mapping(uint256 => uint256))
        public pointsForProof4Request;
    mapping(uint256 => mapping(uint256 => bool)) public claimedProof4Request;

    constructor(address feeCollector_, address videoNFT_) {
        _feeCollector = feeCollector_;
        videoNFT = IERC721(videoNFT_);
    }

    function updateFeeBPS(uint256 fee_) external onlyOwner {
        _feeBPS = fee_;
    }

    function updateFeeCollector(address collector_) external onlyOwner {
        _feeCollector = collector_;
    }

    function updateVideoNFT(address new_) external onlyOwner {
        videoNFT = IERC721(new_);
    }

    function createRequest(
        uint256 time2proof,
        uint256 reward,
        string calldata requestURI
    ) external payable returns (uint256 requestId) {
        uint256 minIn = (reward * (1e5 + _feeBPS)) / 1e5;
        require(msg.value >= minIn, "value sent not enough");

        requestId = requestsCount++;
        uint256 endTime = block.timestamp + time2proof;
        requests[requestId] = Request({
            endTime: endTime,
            reward: reward,
            status: RequestStatus.ACTIVE,
            requester: msg.sender,
            requestUri: requestURI
        });

        // Send fee to collector
        Address.sendValue(payable(_feeCollector), (reward * _feeBPS) / 1e5);
        if (msg.value > minIn) {
            Address.sendValue(payable(msg.sender), msg.value - minIn);
        }

        emit NewRequest(msg.sender, requestId, endTime, reward, requestURI);
    }

    function submitProof(
        address prover,
        uint256 requestId,
        uint256 tokenId
    ) external returns (uint256) {
        return _submitProof(prover, requestId, tokenId);
    }

    function submitDelegatedProof(
        address prover,
        uint256 requestId,
        uint256 tokenId
    ) external onlyOwner returns (uint256 proofId) {
        uint256 gasInitial = gasleft();
        proofId = _submitProof(prover, requestId, tokenId);
        uint256 gasEnd = gasleft();
        transfer(
            requests[requestId].requester,
            owner(),
            (gasInitial - gasEnd) + 21000 // TODO - find right amount of gas for transfer() execurion
        );
    }

    function voteProofs(
        uint256 requestId,
        uint256[] calldata proofsIds,
        uint256[] calldata points
    ) external {
        require(
            proofsIds.length == points.length,
            "check proofsIds and points"
        );

        Request storage request = requests[requestId];

        require(
            request.requester == msg.sender,
            "only requester can cast votes"
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
            "request not in VOTING state"
        );

        uint256 totalVotes = 0;
        for (uint256 i = 0; i < proofsIds.length; i++) {
            uint256 proofPoints = points[i];
            totalVotes += proofPoints;
            pointsForProof4Request[requestId][proofsIds[i]] = proofPoints;
            _sendBounty(requestId, proofsIds[i]);
        }

        require(totalVotes <= TOTAL_VOTES, "too many votes");

        request.status = RequestStatus.CLOSED;
        emit RequestClosed(request.requester, requestId);
    }

    function _sendBounty(uint256 requestId, uint256 proofId) internal {
        uint256 points = pointsForProof4Request[requestId][proofId];
        require(points > 0, "nothing to claim");

        require(!claimedProof4Request[requestId][proofId], "already claimed");

        claimedProof4Request[requestId][proofId] = true;

        uint256 proofReward = (requests[requestId].reward * points) /
            TOTAL_VOTES;

        Address.sendValue(
            (proofsByRequest[requestId][proofId]).verifier,
            proofReward
        );
    }

    function _submitProof(
        address prover,
        uint256 requestId,
        uint256 tokenId
    ) internal returns (uint256 proofId) {
        require(requestId < requestsCount, "request does not exist");
        Request memory request = requests[requestId];
        require(
            request.requester != prover,
            "you cannot prove your own request"
        );
        // make sure verifier is the video creator
        require(videoNFT.ownerOf(tokenId) == prover, "not owner");
        require(request.status == RequestStatus.ACTIVE, "request not ACTIVE");

        proofId = proofsCount4Request[requestId]++;

        proofsByRequest[requestId][proofId] = Proof({
            tokenId: tokenId,
            verifier: payable(prover)
        });

        emit NewProof(prover, requestId, proofId, tokenId);
    }
}
