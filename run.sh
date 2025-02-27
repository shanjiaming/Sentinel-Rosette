#!/usr/bin/env bash

# some safety check: Make sure only A-Z, a-z, 0-9, _ are in EXP_NAME
if [[ "$EXP_NAME" != *[A-Za-z0-9_]* ]]; then
    echo "Error: EXP_NAME contains invalid characters"
    exit 1
fi

if [ -d "out/${EXP_NAME}.sol" ]; then
    rm -r out/${EXP_NAME}.sol
fi
mkdir -p out/${EXP_NAME}.sol
echo "forge script start"
# the no dump run is to ensure the profit is correct
forge script "./sol/${EXP_NAME}.sol" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA"
forge script "./sol/${EXP_NAME}.sol" --rpc-url "https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA" --debug --dump "out/${EXP_NAME}.sol/forge_trace.json"
mkdir -p out/${EXP_NAME}
mv out/${EXP_NAME}.sol/* out/${EXP_NAME}
rm -r out/${EXP_NAME}.sol
cp sol/${EXP_NAME}.sol out/${EXP_NAME}/source_${EXP_NAME}.sol
echo "forge script done"

echo "--------------------------------"
echo "extract_bin start"
python extract_bin.py
echo "extract_bin done"

echo "--------------------------------"
echo "rosette start"
racket -l errortrace -t smartexe.rkt > out/${EXP_NAME}/output.log
echo "rosette done"

echo "--------------------------------"
echo "trace_compare start"
python trace_compare.py
echo "trace_compare done"

# if anything wrong, run this to compare trace
# forge debug ./sol/${EXP_NAME}.sol --rpc-url https://eth-mainnet.g.alchemy.com/v2/P-x0L9coIqzuhfI091DXitR7BzYbABFA
# python forge_debugger_locator.py C s k
