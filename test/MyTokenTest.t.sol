// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", 1000);
    }

    function test_InitialSupply() public {
        assertEq(token.totalSupply(), 1000 * 10 ** 18);
    }

    function test_InitialBalanceGoesToDeployer() public {
        assertEq(token.balanceOf(address(this)), 1000 * 10 ** 18);
    }

    function test_Transfer() public {
        token.transfer(alice, 100 * 10 ** 18);
        assertEq(token.balanceOf(alice), 100 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 900 * 10 ** 18);
    }

    function test_TransferRevertsIfNotEnoughBalance() public {
        vm.expectRevert("not enough balance");
        token.transfer(alice, 9999 * 10 ** 18);
    }

    function test_TransferRevertsToZeroAddress() public {
        vm.expectRevert("zero address");
        token.transfer(address(0), 100 * 10 ** 18);
    }

    function test_Approve() public {
        token.approve(alice, 500 * 10 ** 18);
        assertEq(token.allowance(address(this), alice), 500 * 10 ** 18);
    }

    function test_TransferFrom() public {
        token.approve(alice, 200 * 10 ** 18);
        vm.prank(alice);
        token.transferFrom(address(this), bob, 200 * 10 ** 18);
        assertEq(token.balanceOf(bob), 200 * 10 ** 18);
        assertEq(token.allowance(address(this), alice), 0);
    }

    function test_TransferFromRevertsNoAllowance() public {
        vm.expectRevert("not enough allowance");
        vm.prank(alice);
        token.transferFrom(address(this), bob, 100 * 10 ** 18);
    }

    function test_Mint() public {
        token.mint(alice, 500 * 10 ** 18);
        assertEq(token.balanceOf(alice), 500 * 10 ** 18);
        assertEq(token.totalSupply(), 1500 * 10 ** 18);
    }

    function test_Burn() public {
        token.burn(100 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 900 * 10 ** 18);
        assertEq(token.totalSupply(), 900 * 10 ** 18);
    }

    function test_BurnRevertsIfNotEnoughBalance() public {
        vm.expectRevert("not enough balance");
        token.burn(9999 * 10 ** 18);
    }

    function test_TransferEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit MyToken.Transfer(address(this), alice, 100 * 10 ** 18);
        token.transfer(alice, 100 * 10 ** 18);
    }

    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(this));
        amount = bound(amount, 0, token.balanceOf(address(this)));

        uint256 balanceBefore = token.balanceOf(address(this));
        token.transfer(to, amount);

        assertEq(token.balanceOf(address(this)), balanceBefore - amount);
        assertEq(token.balanceOf(to), amount);
    }

    function testFuzz_Approve(address spender, uint256 amount) public {
        vm.assume(spender != address(0));
        token.approve(spender, amount);
        assertEq(token.allowance(address(this), spender), amount);
    }
}