// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function test_ReadUSDCTotalSupply() public {
        uint256 supply = IERC20(USDC).totalSupply();
        assertGt(supply, 0);
        console.log("USDC Total Supply:", supply);
    }

    function test_USDCDecimals() public {
        (bool ok, bytes memory data) = USDC.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok);
        uint8 dec = abi.decode(data, (uint8));
        assertEq(dec, 6);
        console.log("USDC Decimals:", dec);
    }

    function test_UniswapSwapETHForUSDC() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        vm.deal(address(this), 1 ether);

        uint256 balanceBefore = IERC20(USDC).balanceOf(address(this));

        IUniswapV2Router(ROUTER).swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(this));
        assertGt(balanceAfter, balanceBefore);
        console.log("USDC received:", balanceAfter - balanceBefore);
    }

    function test_GetAmountsOutFromUniswap() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        uint256[] memory amounts = IUniswapV2Router(ROUTER).getAmountsOut(1 ether, path);
        assertGt(amounts[1], 0);
        console.log("Expected USDC for 1 ETH:", amounts[1]);
    }
}