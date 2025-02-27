# Sentinel

This project mainly implements a symbolic EVM in rosette, and it use it to maximize the profit of an attack, given the attack binary, attacker and attacker's balance calculation.


## Requirements:

rosette (and maybe some packages), foundary toolchain(forge, cast, anvil)
python >= 3.5 (and maybe some packages) (for vandal parsing).


## How to run:

Current supported attack:

Bancor
Opyn
Cover
PAID

Other attacks are not supported yet because of unimplemented EVM opcodes / unimplemented cheatcodes/ time or space complexity.

```
export EXP_NAME=ATTACK_NAME
./run.sh
```

Check the result in out/EXP_NAME/result.txt

The results is shown as:

```
FINAL RESULT:
<before_profit> -> <after_profit>
optimal assignments:
<before_args> -> <after_args>
Running Evm time <time>
Solving MaxSMT time <time>
```

What run.sh does:

1. Using forge togenerate attack binary from solidity contract
2. Using forge to run the attack first to dump the trace of running.
3. Use rosette EVM to run attack binary to get the profit, and use symbolic EVM to find the optimal assignments and optimal profit.
4. Compare the trace with the forge dump, and make sure there is no difference.


If you want to add a new attack (not recommended, because it's likely to fail since not tested), you need to do the following:
We start from generate attack bin from solidity contract.

Copy a DefiHackLab contract to sol/ and apply AIprompteasy.txt (or AIpromptlowlevel.txt) (make sure the rules are followed), and you get sol/ATTACK_NAME.sol

Then you can use

```
export EXP_NAME=ATTACK_NAME
./run.sh
```



## For developer

Test evm correctness:
```
python debugcompare.py
forge debug ./sol/${EXP_NAME}.sol --rpc-url https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA
```
(parameters you may want if do personalization: `--tc BancorExploit --sig "testsafeTransfer()" --fork-block-number 10307563`)

For developer debugging to match evm trace, you may need pyautogui to use forge_debugger_locator.py.
you can use forge_debugger_locator.py to locate the difference in the debugger compare your result with the correct one, and you may use pyautogui to simulate the keyboard input.