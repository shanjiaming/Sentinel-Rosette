import json
import re
import os
exp_name = os.environ["EXP_NAME"]
with open(f'out/{exp_name}/sentinel_trace.json', 'r') as file:
    data__my = json.load(file)

with open(f'out/{exp_name}/forge_trace.json', 'r') as file:
    data_ans = json.load(file)

def translate_stack_string(s):
    # Extract hexadecimal values from the string using a regex.
    hex_values = re.findall(r'E\[(0x[0-9a-fA-F]+)\]', s)
    return hex_values

print(len(data__my['debug_arena']), len(data_ans['debug_arena']))


# to add: blockrandkey -> (chapter_index, jumpdest_count, steps_after_jumpdest)

SearchingBRK = 0

# if has para, SearchingBRK = para
import sys
if len(sys.argv) > 1:
    SearchingBRK = int(sys.argv[1])

for chapter_index, (chapter_my, chapter_ans) in enumerate(zip(data__my['debug_arena'], data_ans['debug_arena'])):
    start_idx = 0
    jumpdest_count = 0
    steps_after_jumpdest = 0

    for i, step_ans in enumerate(chapter_ans['steps']):
        step_my = chapter_my['steps'][start_idx]
        # Update the ans locator based on opcode.
        if step_ans['op'] == 0x5b:
            jumpdest_count += 1
            steps_after_jumpdest = 0
        else:
            steps_after_jumpdest += 1

        if step_ans['pc'] == int(step_my['pc'], 16):
            contract_ans = step_ans['contract']
            contract_my = "0x" + step_my['contract']
            stack_ans = step_ans['stack'][::-1]
            stack_my = translate_stack_string(step_my['stack'])

            # Prepare the locator tuple for ans
            ans_locator = (chapter_index, jumpdest_count, steps_after_jumpdest)
            my_locator = step_my['blockrandkey']

            if SearchingBRK:
                if my_locator == SearchingBRK:
                    print("Found!", SearchingBRK)
                    print("python forge_debugger_locator.py", *ans_locator)
                    print("storage_change:", step_ans['storage_change'])

            if contract_ans != contract_my or stack_ans != stack_my:
                if contract_ans != contract_my:
                    print("****************************************")
                    print("ERROR: CONTRACT MISMATCH DETECTED!")
                    print("python forge_debugger_locator.py", *ans_locator)
                    print("MY locator (blockrandkey):", my_locator)
                    print("ANS contract:", contract_ans, "| MY contract:", contract_my)
                    print("****************************************")
                if stack_ans != stack_my:
                    # print("****************************************")
                    # print("ERROR: STACK MISMATCH DETECTED (BEFORE MASKING)!")
                    # print("python forge_debugger_locator.py", *ans_locator)
                    # print("MY locator (blockrandkey):", my_locator)
                    error_flag = False
                    if len(stack_ans) == len(stack_my):
                        masked_ans = stack_ans[:]
                        masked_my = stack_my[:]
                        # Mask out positions where my stack has the specific value.
                        for j in range(len(stack_my)):
                            if stack_my[j] == "0x1ffffffffffffffffffffffffffffffffffff":
                                masked_ans[j] = None
                                masked_my[j] = None
                        if masked_ans != masked_my:
                            error_flag = True
                    else:
                        error_flag = True

                    if error_flag:
                        print("****************************************")
                        print("ERROR: STACK MISMATCH DETECTED (AFTER MASKING)!")
                        print("python forge_debugger_locator.py", *ans_locator)
                        print("MY locator (blockrandkey):", my_locator)
                        print(f"Chapter: {chapter_index}")
                        print(f"pc: {hex(step_ans['pc'])}")
                        print(f"blockrandkey: {step_my['blockrandkey']}")
                        print(f"block-idx: {step_my['block-idx']}")
                        print(f"contract: {contract_ans}")
                        print(f"op: {hex(step_ans['op'])}")
                        print(f"jumpdest_count: {jumpdest_count}")
                        print(f"steps_after_jumpdest: {steps_after_jumpdest}")
                        print("Differences after masking:")
                        for j in range(len(masked_ans)):
                            if masked_ans[j] != masked_my[j]:
                                print(f"  Index {j}:")
                                print(f"    ans stack = {masked_ans[j]}")
                                print(f"    my  stack = {masked_my[j]}")
                        print("\nOriginal stack_ans:", stack_ans)
                        print("Original stack_my:", stack_my)
                        print("****************************************")
                        assert False
            start_idx += 1
            if start_idx == len(chapter_my['steps']):
                break

    # After processing ans steps, check if there are any unmatched steps in my code.
    if start_idx < len(chapter_my['steps']):
        # Use the last ans locator as the reference.
        ans_locator = (chapter_index, jumpdest_count, steps_after_jumpdest)
        print("============================================")
        print(f"ERROR: Unmatched steps in 'my' code detected in chapter {chapter_index}!")
        print("python forge_debugger_locator.py", *ans_locator)
        for idx in range(start_idx, len(chapter_my['steps'])):
            step = chapter_my['steps'][idx]
            print(f"  Unmatched step at index {idx}: {step}")
            print("  MY locator (blockrandkey):", step['blockrandkey'])
        print("============================================")
        raise Exception(f"In chapter {chapter_index}, there are unmatched steps in 'my'. Total steps: {len(chapter_my['steps'])}, matched: {start_idx}.")

if len(data__my['debug_arena']) != len(data_ans['debug_arena']):
    print("============================================")
    print("ERROR: Chapter length mismatch!")
    print("python forge_debugger_locator.py", *ans_locator)
    print("MY locator (blockrandkey):", my_locator)
    print("============================================")
    assert False
