# post_compile.py
import sys
import os
import json
import shutil

def main():
    exp_name = os.environ["EXP_NAME"]

    out_dir = os.path.join("out", exp_name)
    
    if not os.path.exists(out_dir):
        print(f"output dir {out_dir} not exist, please check if the compilation is successful?")
        sys.exit(1)
    
    # traverse all files in the output directory, process files with only one dot and extension .json
    found = False
    for filename in os.listdir(out_dir):
        file_path = os.path.join(out_dir, filename)
        if os.path.isfile(file_path):
            # check if the file name has only one dot and extension is .json
            if (not filename.endswith("trace.json")) and filename.endswith(".json") and filename.count('.') == 1:
                found = True
                # for example, filename is "Simple.json"
                contract_name = filename.split('.')[0]
                json_path = file_path
                bin_path = os.path.join(out_dir, f"{contract_name}.bin")
                
                try:
                    with open(json_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    
                    # extract deployedBytecode -> object field
                    deployed_bytecode = data["deployedBytecode"]["object"]
                    # if deployed_bytecode.startswith("0x"):
                        # deployed_bytecode = deployed_bytecode[2:]
                    
                    # write to .bin file
                    with open(bin_path, "w", encoding="utf-8") as f:
                        f.write(deployed_bytecode)
                    
                    print(f"generated {bin_path} file.")
                except FileNotFoundError:
                    print(f"not found {json_path}, please check if the compilation is successful?")
                except KeyError:
                    print(f"not found [deployedBytecode][object] field in {json_path}, please check the compilation output.")
                except Exception as e:
                    print(f"error when processing {json_path}: {e}")
    
    if not found:
        print("not found json file in the output directory.")

if __name__ == "__main__":
    main()
