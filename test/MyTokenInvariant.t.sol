// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract TransferHandler is Test {
    MyToken public token;
    address[] public actors;

    constructor(MyToken _token) {
        token = _token;
        actors.push(address(0x11));
        actors.push(address(0x22));
        actors.push(address(0x33));

        for (uint256 i = 0; i < actors.length; i++) {
            token.mint(actors[i], 1000 * 10 ** 18);
        }
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, token.balanceOf(from));
        
        vm.prank(from);
        bool success = token.transfer(to, amount);
        require(success, "transfer failed");
    }
}

contract MyTokenInvariantTest is Test {
    MyToken token;
    TransferHandler handler;
    address[] actors;

    function setUp() public {
        token = new MyToken("Test", "TST", 0);
        handler = new TransferHandler(token);
        
        targetContract(address(handler));

        actors.push(address(0x11));
        actors.push(address(0x22));
        actors.push(address(0x33));
    }

    function invariant_TotalSupplyNeverChangesFromTransfers() public view {
        assertEq(token.totalSupply(), 3000 * 10 ** 18);
    }

    function invariant_NoAddressExceedsTotalSupply() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            assertLe(token.balanceOf(actors[i]), token.totalSupply());
        }
    }
}