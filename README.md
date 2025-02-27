# Sentinel

This project mainly implements a symbolic EVM in rosette, and it use it to maximize the profit of an attack, given the attack binary, attacker and attacker's balance calculation.


## Requirements:

### Docker

If you want to use docker:

```bash
docker build -t sentinel-rosette .
docker run -it sentinel-rosette bash
```

Then git clone this repo in the docker container.

By this way, you don't need to install dependencies.

### Install dependencies

If you want to install dependencies by yourself, you can do the following:

Install foundary toolchain(forge, cast, anvil)
```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

rosette (and maybe some packages), 


Install racket (suppose you are linux, otherwise see https://download.racket-lang.org/)
```bash
wget https://download.racket-lang.org/installers/8.15/racket-8.15-x86_64-linux-cs.sh
sudo sh racket-8.15-x86_64-linux-cs.sh
```
Do you want a Unix-style distribution? 
...
Enter yes/no (default: no) > no

Where do you want to install the "racket" directory tree?
  1 - /usr/racket [default]
  2 - /usr/local/racket
  3 - ~/racket (/root/racket)
  4 - ./racket (here)
  Or enter a different "racket" directory to install in.
> 2
...
If you want to install new system links within the "bin", "man"
  and "share/applications" subdirectories of a common directory prefix
  (for example, "/usr/local") then enter the prefix of an existing
  directory that you want to use.  This might overwrite existing symlinks,
  but not files.
(default: skip links) > /usr/local


Then run
```bash
raco pkg install rosette
raco pkg install debug
```
Would you like to install these dependencies? [Y/n/a/c/?] Y

Install python >= 3.5 (and maybe some packages) (for vandal parsing).

## How to run:

Current supported attack:

Bancor
Opyn
Cover
PAID

Other attacks are not supported yet because of unimplemented EVM opcodes / unimplemented cheatcodes/ time or space complexity.

```
export EXP_NAME=ATTACK_NAME
bash run.sh
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
bash run.sh
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