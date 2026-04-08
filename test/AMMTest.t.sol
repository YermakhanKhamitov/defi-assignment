// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/MyToken.sol";

contract AMMTest is Test {
    AMM amm;
    MyToken tokenA;
    MyToken tokenB;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        tokenA = new MyToken("Token A", "TKA", 1000000);
        tokenB = new MyToken("Token B", "TKB", 1000000);
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.transfer(alice, 100000 * 10 ** 18);
        tokenB.transfer(alice, 100000 * 10 ** 18);
        tokenA.transfer(bob, 100000 * 10 ** 18);
        tokenB.transfer(bob, 100000 * 10 ** 18);
    }

    function test_AddLiquidityFirstProvider() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        uint256 lp = amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        assertEq(amm.reserveA(), 1000 * 10 ** 18);
        assertEq(amm.reserveB(), 1000 * 10 ** 18);
        assertGt(lp, 0);
    }

    function test_AddLiquiditySecondProvider() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), 500 * 10 ** 18);
        tokenB.approve(address(amm), 500 * 10 ** 18);
        uint256 lp = amm.addLiquidity(500 * 10 ** 18, 500 * 10 ** 18);
        vm.stopPrank();

        assertGt(lp, 0);
        assertEq(amm.reserveA(), 1500 * 10 ** 18);
    }

    function test_RemoveLiquidityPartial() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        uint256 lp = amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);

        amm.lpToken().approve(address(amm), lp / 2);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(lp / 2);
        vm.stopPrank();

        assertGt(outA, 0);
        assertGt(outB, 0);
        assertEq(amm.reserveA(), 1000 * 10 ** 18 - outA);
    }

    function test_RemoveLiquidityFull() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        uint256 lp = amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);

        amm.lpToken().approve(address(amm), lp);
        amm.removeLiquidity(lp);
        vm.stopPrank();

        assertEq(amm.reserveA(), 0);
        assertEq(amm.reserveB(), 0);
    }

    function test_SwapAForB() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 balanceBefore = tokenB.balanceOf(bob);

        vm.startPrank(bob);
        tokenA.approve(address(amm), 10 * 10 ** 18);
        amm.swap(address(tokenA), 10 * 10 ** 18, 0);
        vm.stopPrank();

        assertGt(tokenB.balanceOf(bob), balanceBefore);
    }

    function test_SwapBForA() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 balanceBefore = tokenA.balanceOf(bob);

        vm.startPrank(bob);
        tokenB.approve(address(amm), 10 * 10 ** 18);
        amm.swap(address(tokenB), 10 * 10 ** 18, 0);
        vm.stopPrank();

        assertGt(tokenA.balanceOf(bob), balanceBefore);
    }

    function test_KIncreasesOrStaysAfterSwap() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(bob);
        tokenA.approve(address(amm), 10 * 10 ** 18);
        amm.swap(address(tokenA), 10 * 10 ** 18, 0);
        vm.stopPrank();

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }

    function test_SlippageProtectionReverts() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), 10 * 10 ** 18);
        vm.expectRevert("slippage: too little received");
        amm.swap(address(tokenA), 10 * 10 ** 18, 999999 * 10 ** 18);
        vm.stopPrank();
    }

    function test_ZeroAmountSwapReverts() public {
        vm.expectRevert("zero amount");
        amm.swap(address(tokenA), 0, 0);
    }

    function test_ZeroAmountAddLiquidityReverts() public {
        vm.expectRevert("zero amounts");
        amm.addLiquidity(0, 0);
    }

    function test_LargeSwapHighPriceImpact() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 1000 * 10 ** 18);
        tokenB.approve(address(amm), 1000 * 10 ** 18);
        amm.addLiquidity(1000 * 10 ** 18, 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 smallSwapOut = amm.getAmountOut(1 * 10 ** 18, 1000 * 10 ** 18, 1000 * 10 ** 18);
        uint256 largeSwapOut = amm.getAmountOut(500 * 10 ** 18, 1000 * 10 ** 18, 1000 * 10 ** 18);

        uint256 smallPrice = smallSwapOut * 1000 / (1 * 10 ** 18);
        uint256 largePrice = largeSwapOut * 1000 / (500 * 10 ** 18);

        assertLt(largePrice, smallPrice);
    }

    function test_GetAmountOutCorrect() public {
        uint256 out = amm.getAmountOut(100 * 10 ** 18, 1000 * 10 ** 18, 1000 * 10 ** 18);
        assertGt(out, 0);
        assertLt(out, 100 * 10 ** 18);
    }

    function test_InvalidTokenSwapReverts() public {
        vm.expectRevert("invalid token");
        amm.swap(address(0x999), 10 * 10 ** 18, 0);
    }

    function test_ZeroLPRemoveLiquidityReverts() public {
        vm.expectRevert("zero lp");
        amm.removeLiquidity(0);
    }

    function testFuzz_Swap(uint256 amountIn) public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 10000 * 10 ** 18);
        tokenB.approve(address(amm), 10000 * 10 ** 18);
        amm.addLiquidity(10000 * 10 ** 18, 10000 * 10 ** 18);
        vm.stopPrank();

        amountIn = bound(amountIn, 1, 1000 * 10 ** 18);

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.startPrank(bob);
        tokenA.approve(address(amm), amountIn);
        amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();

        assertGe(amm.reserveA() * amm.reserveB(), kBefore);
    }
}