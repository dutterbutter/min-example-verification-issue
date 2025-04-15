// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ERC2771Context} from "openzeppelin-contracts/metatx/ERC2771Context.sol";

contract Counter is EIP712("Caller", "1"), ERC2771Context(address(this)) {
    uint256 public count;
    event Increment(uint256 newCount);
    event Decrement(uint256 newCount);

    constructor(uint256 initialCount) {
        count = initialCount;
    }

    // Function to increment the counter by 1
    function increment() public {
        count += 1;
        emit Increment(count);
    }

    // Function to decrement the counter by 1
    // It ensures the counter does not go below zero.
    function decrement() public {
        require(count > 0, "Counter: count cannot be negative");
        count -= 1;
        emit Decrement(count);
    }
}
