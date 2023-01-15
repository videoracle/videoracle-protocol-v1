// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ImAnEscrow is Ownable2Step, ReentrancyGuard, EIP712 {
    using Address for address;
    using ECDSA for bytes32;

    struct Request {
        string id;
        address bountyAsset;
        uint256 bountyAmount;
        uint256 feeAmount;
        bool closed;
    }
    struct DispatchVoucher {
        string reqId;
        address[] receivers;
        uint256[] amounts;
    }

    // address private _feeJar;

    mapping(string => Request) private requests;

    constructor() EIP712("VideOracleEscrow", "1") {}

    // function updateFeeJar(address jar) external onlyOwner {
    //     _feeJar = jar;
    // }

    //CREATE REQUEST
    /**
     * @notice Voodoo magic required for vouchers
     */
    function requestTypeHash() internal pure returns (bytes32) {
        return
            keccak256(
                "Request(string id, address bountyAsset, uint bountyAmount, uint feeAmount, bool closed)"
            );
    }

    /**
     * @notice Voodoo magic required for vouchers
     */
    function _hashRequest(Request calldata req)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        requestTypeHash(),
                        req.id,
                        req.bountyAsset,
                        req.bountyAmount,
                        req.feeAmount,
                        req.closed
                    )
                )
            );
    }

    /**
     * @notice Create a Request
     * @dev The customer will be handed a voucher that let's it use this contract
     * TBD - for privacy-preserving reasons it is strongly suggested to have this called by a burner wallet
     * and check off-chain that the funds have been transferred
     * @param request - a request
     * @param signedMessage - A voucher signed by the owner
     */
    function createRequest(
        Request calldata request,
        bytes calldata signedMessage
    ) external payable {
        address signer = _hashRequest(request).recover(signedMessage);
        require(signer == owner(), "INVALID_SIGNER");

        requests[request.id] = request;
        // The below is only needed if not using a burner wallet
        // if (request.bountyAsset == address(0)) {
        //     uint256 minIn = (request.bountyAmount + request.feeAmount);
        //     require(msg.value >= minIn, "INVALID_AMOUT");
        //     // Send fee to collector
        //     Address.sendValue(payable(_feeJar), request.feeAmount);
        //     if (msg.value > minIn) {
        //         Address.sendValue(payable(_msgSender()), msg.value - minIn);
        //     }
        // } else {
        //     IERC20 token = IERC20(request.bountyAsset);
        //     token.transferFrom(_msgSender(), _feeJar, request.feeAmount);
        //     token.transferFrom(
        //         _msgSender(),
        //         address(this),
        //         request.bountyAmount
        //     );
        // }
    }

    /**
     * @dev burner wallets should be used in this situation as well
     */
    function cancelRequest(
        Request calldata request,
        bytes calldata signedMessage
    ) external payable {
        address signer = _hashRequest(request).recover(signedMessage);
        require(signer == owner(), "INVALID_SIGNER");

        Request memory req = requests[request.id];
        require(!req.closed, "UNAUTHORIZED");
        requests[req.id].closed = true;
        // Uncomment if not using burner wallets
        // if (req.bountyAsset == address(0)) {
        //     Address.sendValue(payable(requesters[req.id]), req.bountyAmount);
        // } else {
        //     IERC20(req.bountyAsset).transfer(
        //         requesters[req.id],
        //         req.bountyAmount
        //     );
        // }
    }

    // BOUNTIES
    /**
     * @notice Voodoo magic required for vouchers
     */
    function dispatchTypeHash() internal pure returns (bytes32) {
        return
            keccak256(
                "DispatchVoucher(string reqId, address[] receivers, uint[] amounts)"
            );
    }

    /**
     * @notice Voodoo magic required for vouchers
     */
    function _hashDispatch(DispatchVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        dispatchTypeHash(),
                        voucher.reqId,
                        voucher.receivers,
                        voucher.amounts
                    )
                )
            );
    }

    /**
     * @dev you guessed it - burner wallet should be used here too
     */
    function dispatchBounties(
        DispatchVoucher calldata voucher,
        bytes calldata signedMessage
    ) external {
        address signer = _hashDispatch(voucher).recover(signedMessage);
        require(signer == owner(), "INVALID_SIGNER");

        uint256 totalSent = 0;
        Request memory req = requests[voucher.reqId];
        require(!req.closed, "CLOSED");
        for (uint256 i; i < voucher.receivers.length; ++i) {
            totalSent += voucher.amounts[i];
            if (req.bountyAsset == address(0)) {
                Address.sendValue(
                    payable(voucher.receivers[i]),
                    voucher.amounts[i]
                );
            } else {
                IERC20(req.bountyAsset).transfer(
                    voucher.receivers[i],
                    voucher.amounts[i]
                );
            }
        }
        require(totalSent <= req.bountyAmount, "INVALID_AMOUNT");
        requests[voucher.reqId].closed = true;
    }
}
