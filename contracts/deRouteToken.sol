// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract deRouteToken is ERC20("deRoute Token", "DRT") {

    constructor() {
        _mint(msg.sender, 1e28);  // 10 billion, 18 decimals
    }
}
