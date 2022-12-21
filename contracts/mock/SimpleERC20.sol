// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleERC20 is ERC20 {
    constructor(address[] memory _users) ERC20("SimpleERC20", "SERC20") {
        for (uint256 i = 0; i < _users.length; i++) {
            _mint(_users[i], 100 * (10**18));
        }
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
