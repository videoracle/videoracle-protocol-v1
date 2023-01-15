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

    struct CustomerVoucher {
        address entity;
        uint256 feeBPS;
    }
    struct ClaimVoucher {
        string reqId;
        address to;
        uint256 amount;
    }
    struct CustomerConfig {
        bool active;
        uint256 feeBPS;
    }
    struct Request {
        string id;
        address bountyAsset;
        uint256 bountyAmount;
        bool closed;
    }

    address private _feeJar;

    mapping(string => address) private requesters;
    mapping(string => Request) private requests;
    mapping(address => CustomerConfig) private customerConfigs;

    constructor() EIP712("VideOracleEscrow", "1") {}

    modifier onlyCustomer() {
        require(customerConfigs[_msgSender()].active, "UNAUTHORIZED");
        _;
    }

    // CUSTOMER
    function setCustomerConfig(address customer, CustomerConfig calldata config)
        external
        onlyOwner
    {
        customerConfigs[customer] = config;
    }

    /**
     * @notice Voodoo magic required for vouchers
     */
    function customerTypeHash() internal pure returns (bytes32) {
        return keccak256("Customer(address entity,uint feeBPS)");
    }

    /**
     * @notice Voodoo magic required for vouchers
     */
    function _hashCustomer(CustomerVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        customerTypeHash(),
                        voucher.entity,
                        voucher.feeBPS
                    )
                )
            );
    }

    /**
     * @notice Become a customer
     * @dev The customer will be handed a voucher that let's it use this contract
     * @param voucher - a voucher
     * @param signedMessage - A voucher signed by the owner
     */
    function becomeCustomer(
        CustomerVoucher calldata voucher,
        bytes calldata signedMessage
    ) external {
        address signer = _hashCustomer(voucher).recover(signedMessage);
        require(signer == owner(), "INVALID_SIGNER");
        customerConfigs[voucher.entity].feeBPS = voucher.feeBPS;
        customerConfigs[voucher.entity].active = true;
    }

    //CREATE REQUEST
    /**
     * @notice Voodoo magic required for vouchers
     */
    function requestTypeHash() internal pure returns (bytes32) {
        return
            keccak256(
                "Request(string id, address bountyAsset, uint bountyAmount, bool closed)"
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
                        req.closed
                    )
                )
            );
    }

    /**
     * @notice Create a Request
     * @dev The customer will be handed a voucher that let's it use this contract
     * @param request - a request
     * @param signedMessage - A voucher signed by the owner
     */
    function createRequest(
        Request calldata request,
        bytes calldata signedMessage
    ) external payable onlyCustomer {
        address signer = _hashRequest(request).recover(signedMessage);
        require(signer == owner(), "INVALID_SIGNER");

        requests[request.id] = request;
        uint256 customerFee = customerConfigs[_msgSender()].feeBPS;

        uint256 feeAmt = (request.bountyAmount * customerFee) / 1e5;
        if (request.bountyAsset == address(0)) {
            uint256 minIn = (request.bountyAmount + feeAmt);
            require(msg.value >= minIn, "INVALID_AMOUT");
            requesters[request.id] = _msgSender();
            // Send fee to collector
            Address.sendValue(payable(_feeJar), feeAmt);
            if (msg.value > minIn) {
                Address.sendValue(payable(_msgSender()), msg.value - minIn);
            }
        } else {
            IERC20 token = IERC20(request.bountyAsset);
            token.transferFrom(_msgSender(), _feeJar, feeAmt);
            token.transferFrom(
                _msgSender(),
                address(this),
                request.bountyAmount
            );
        }
    }

    function dispatchBounties(
        string calldata reqId,
        address[] calldata receivers,
        uint256[] calldata amounts
    ) external onlyCustomer {
        uint256 totalSent = 0;
        Request memory req = requests[reqId];
        require(requesters[reqId] == _msgSender(), "UNATHORIZED");
        require(!req.closed, "CLOSED");
        for (uint256 i; i < receivers.length; ++i) {
            totalSent += amounts[i];
            if (req.bountyAsset == address(0)) {
                Address.sendValue(payable(receivers[i]), amounts[i]);
            } else {
                IERC20(req.bountyAsset).transfer(receivers[i], amounts[i]);
            }
        }
        require(totalSent <= req.bountyAmount, "INVALID_AMOUNT");
        requests[reqId].closed = true;
    }
}
