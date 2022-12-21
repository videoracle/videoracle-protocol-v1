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

    struct Answer {
        uint256 answerVideoId;
        address payable answerer;
    }

    mapping(uint256 => mapping(uint256 => Answer)) public answersByRequest;
    mapping(uint256 => uint256) public answersCount4Request;
    mapping(uint256 => mapping(uint256 => uint256)) public pointsForAnswer4Request;
    mapping(uint256 => mapping(uint256 => bool)) public claimedAnswer4Request;

    event NewRequest(address indexed src, uint256 requestId, string requestUri);

    function createRequest(uint256 time2answer, uint256 reward, string calldata requestURI) public payable returns(uint256 requestId) {
        require(msg.value >= reward, 'value sent not enough');

        requestId = requestsCount++;
        requests[requestId] = Request({
            endTime: block.timestamp + time2answer,
            reward: reward,
            status: RequestStatus.ACTIVE,
            requester: msg.sender,
            requestUri: requestURI
        });

        if (msg.value > reward) {
            Address.sendValue(payable(msg.sender),  msg.value - reward);
        }

        emit NewRequest(msg.sender, requestId, requestURI);
    }

    function answerRequest(uint256 requestId, uint256 answerVideoId) public returns(uint256 answerId) {
        require(requestId < requestsCount, 'request does not exist');

        Request memory request = requests[requestId];

        require(request.requester != msg.sender, 'you cannot answer your own request');

        require(request.status == RequestStatus.ACTIVE, 'request not in active state');

        answerId = answersCount4Request[requestId]++;

        answersByRequest[requestId][answerId] = Answer({
            answerVideoId: answerVideoId,
            answerer: payable(msg.sender)
        });
    }

    function voteAnswers(uint256 requestId, uint256[] calldata answersIds, uint256[] calldata points) public {
        require(answersIds.length == points.length, 'check answersIds and points');

        Request storage request = requests[requestId];

        require(request.requester == msg.sender, 'only answerer can vote their own requests');

        if (request.status == RequestStatus.ACTIVE && request.endTime >= block.timestamp) {
            request.status = RequestStatus.VOTING;
        }

        require(request.status == RequestStatus.VOTING, 'request not in voting state');

        uint256 totalVotes = 0;
        for(uint256 i = 0; i < answersIds.length; i++) {
            uint256 answerPoints = points[i];
            totalVotes += answerPoints;
            pointsForAnswer4Request[requestId][answersIds[i]] = answerPoints;
        }

        require(totalVotes <= TOTAL_VOTES, 'too many votes');

        request.status = RequestStatus.CLOSED;
    }

    function claim(uint256 requestId, uint256 answerId) public {
        uint256 points = pointsForAnswer4Request[requestId][answerId];
        require(points > 0, 'no points to your request');

        require(claimedAnswer4Request[requestId][answerId] == false, 'already claimed');

        claimedAnswer4Request[requestId][answerId] = true;

        uint256 answerReward = requests[requestId].reward * points / TOTAL_VOTES;

        Address.sendValue(
            (answersByRequest[requestId][answerId]).answerer,
            answerReward
        );
    }
}
