// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract GasTank is ReentrancyGuard {
    event Supply(address indexed from, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(address indexed beneficiary, uint256 value);

    mapping(address => uint256) private _gasLeft;

    function supply(address beneficiary) public payable nonReentrant {
        _gasLeft[beneficiary] += msg.value;
        emit Supply(beneficiary, msg.value);
    }

    function transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        _gasLeft[from] -= value;
        Address.sendValue(payable(to), value);
        emit Transfer(from, to, value);
    }

    function withdraw(address recipient, uint256 value) public nonReentrant {
        _gasLeft[msg.sender] -= value;
        Address.sendValue(payable(recipient), value);
    }
}
