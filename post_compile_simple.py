# post_compile.py
import sys
import os
import json
import shutil
def main():
    if len(sys.argv) < 2:
        print("用法: python post_compile.py <path-to-sol-file>")
        sys.exit(1)
    
    # 从命令行参数获取 .sol 源文件路径，比如 "solc_output/Simple17/Simple17.sol"
    sol_file_path = sys.argv[1]
    # 取得文件名，比如 "Simple17.sol"
    sol_filename = os.path.basename(sol_file_path)  
    # 针对本例，Forge 会在 out/Simple17.sol/Simple.json 生成相应编译产物
    json_path = f"out/{sol_filename}/Simple.json"
    bin_path  = f"out/{sol_filename}/Simple.bin"

    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        shutil.copy(sol_file_path, f"out/{sol_filename}/Simple.sol")
        # 找到 "deployedBytecode" -> "object"
        deployed_bytecode = data["deployedBytecode"]["object"]
        # 如果以 "0x" 开头，去掉前缀
        if deployed_bytecode.startswith("0x"):
            deployed_bytecode = deployed_bytecode[2:]
        
        # 写入到 .bin 文件
        with open(bin_path, "w", encoding="utf-8") as f:
            f.write(deployed_bytecode)

        print(f"已生成 {bin_path} 文件。")
    except FileNotFoundError:
        print(f"未找到 {json_path}，请确认编译是否成功？")
    except KeyError:
        print("JSON 中未找到 [deployedBytecode][object] 字段，请检查编译产物。")

if __name__ == "__main__":
    main()
