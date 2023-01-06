// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
// import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

// import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

// import {GasTank} from "./GasTank.sol";
// import {VideOracle} from "./VideOracle.sol";

// contract Forwarder is Ownable2Step, EIP712, GasTank {
//     using Counters for Counters.Counter;
//     using ECDSA for bytes32;

//     struct ForwardRequest {
//         address from;
//         address to;
//         uint256 value;
//         uint256 gas;
//         uint256 nonce;
//         bytes data;
//     }

//     bytes32 private constant _TYPEHASH =
//         keccak256(
//             "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
//         );

//     // Executor can only call callee
//     VideOracle public callee;
//     mapping(address => Counters.Counter) private _nonces;

//     constructor(address video) EIP712("VideOracleForwarder", "1") {
//         callee = VideOracle(video);
//     }

//     function updateCallee(address _new) external onlyOwner {
//         callee = VideOracle(_new);
//     }

//     function getNonce(address from) public view returns (uint256) {
//         return _nonces[from].current();
//     }

//     function verify(ForwardRequest calldata req, bytes calldata signature)
//         public
//         view
//         returns (bool)
//     {
//         address signer = _hashTypedDataV4(
//             keccak256(
//                 abi.encode(
//                     _TYPEHASH,
//                     req.from,
//                     req.to,
//                     req.value,
//                     req.gas,
//                     req.nonce,
//                     keccak256(req.data)
//                 )
//             )
//         ).recover(signature);
//         return
//             req.to == address(callee) &&
//             signer == req.from &&
//             _nonces[req.from].current() == req.nonce;
//     }

//     function submitDelegatedProof(
//         ForwardRequest calldata req,
//         bytes calldata signature
//     ) external onlyOwner returns (bool, bytes memory) {
//         uint256 gasBeginning = gasleft();
//         require(verify(req, signature), "signature mismatch");

//         return (success, returndata);
//     }
// }
