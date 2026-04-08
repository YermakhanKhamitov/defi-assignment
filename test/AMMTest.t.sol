// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AMM} from "../src/AMM.sol";
import {MyToken} from "../src/MyToken.sol";

contract AMMTest is Test {
    AMM amm;
    MyToken tokenA;
    MyToken tokenB;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        tokenA = new MyToken("Token A", "TKA", 1_000_000);
        tokenB = new MyToken("Token B", "TKB", 1_000_000);
        amm = new AMM(address(tokenA), address(tokenB));

        require(tokenA.transfer(alice, 100_000 * 1e18));
        require(tokenB.transfer(alice, 100_000 * 1e18));
        require(tokenA.transfer(bob, 100_000 * 1e18));
        require(tokenB.transfer(bob, 100_000 * 1e18));
    }

    function test_AddLiquidityFirst() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 1e18);
        tokenB.approve(address(amm), 1000 * 1e18);
        uint256 lp = amm.addLiquidity(1000 * 1e18, 1000 * 1e18);
        vm.stopPrank();

        assertEq(amm.reserveA(), 1000 * 1e18);
        assertEq(lp, 1000 * 1e18);
    }

    function test_AddLiquiditySecond() public {
        test_AddLiquidityFirst();
        vm.startPrank(bob);
        tokenA.approve(address(amm), 500 * 1e18);
        tokenB.approve(address(amm), 500 * 1e18);
        amm.addLiquidity(500 * 1e18, 500 * 1e18);
        vm.stopPrank();
        assertEq(amm.reserveA(), 1500 * 1e18);
    }

    function test_RemoveLiquidityFull() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 1e18);
        tokenB.approve(address(amm), 1000 * 1e18);
        uint256 lp = amm.addLiquidity(1000 * 1e18, 1000 * 1e18);
        amm.lpToken().approve(address(amm), lp);
        amm.removeLiquidity(lp);
        vm.stopPrank();
        assertEq(amm.reserveA(), 0);
    }

    function test_SwapAForB() public {
        test_AddLiquidityFirst();
        vm.startPrank(bob);
        tokenA.approve(address(amm), 10 * 1e18);
        amm.swap(address(tokenA), 10 * 1e18, 0);
        vm.stopPrank();
        assertGt(tokenB.balanceOf(bob), 100_000 * 1e18);
    }

    function test_SlippageProtection() public {
        test_AddLiquidityFirst();
        vm.startPrank(bob);
        tokenA.approve(address(amm), 10 * 1e18);
        uint256 expected = amm.getAmountOut(10 * 1e18, 1000 * 1e18, 1000 * 1e18);
        vm.expectRevert("slippage: too little received");
        amm.swap(address(tokenA), 10 * 1e18, expected + 1);
        vm.stopPrank();
    }

    function test_ZeroAmountAddLiquidityReverts() public {
        vm.expectRevert("zero amounts");
        amm.addLiquidity(0, 100);
    }

    function test_InvalidTokenSwapReverts() public {
        vm.expectRevert("invalid token");
        amm.swap(address(0xdead), 100, 0);
    }

    function testFuzz_SwapInvariant(uint256 amountIn) public {
        test_AddLiquidityFirst();
        amountIn = bound(amountIn, 1e15, 500 * 1e18);
        uint256 kBefore = amm.reserveA() * amm.reserveB();
        vm.startPrank(bob);
        tokenA.approve(address(amm), amountIn);
        amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();
        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }
}