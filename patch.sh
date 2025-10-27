#!/bin/bash

# 参数检查
if [[ $# -ne 2 ]]; then
    echo "用法: $0 <源目录> <目标目录>"
    echo "示例: $0 a b"
    exit 1
fi

A_DIR="$1"
B_DIR="$2"

# 检查目录是否存在
if [[ ! -d "$A_DIR" ]]; then
    echo "错误: 目录 '$A_DIR' 不存在"
    exit 1
fi

if [[ ! -d "$B_DIR" ]]; then
    echo "错误: 目录 '$B_DIR' 不存在"
    exit 1
fi

# 创建补丁目录
mkdir -p patches

echo "比较目录: $A_DIR -> $B_DIR"

# 遍历B目录中的所有文件
find "$B_DIR" -type f | while read b_file; do
    # 获取相对于B目录的路径
    relative_path="${b_file#$B_DIR/}"
    
    # 构建A目录中的对应文件路径（直接对应，不跳过任何层级）
    a_file="$A_DIR/$relative_path"
    
    # 检查A目录中是否存在对应文件
    if [[ -f "$a_file" ]]; then
        # 生成补丁文件名（保持原文件名）
	if [[ $all_in == 1 ]]; then
            patch_name="patches/$(basename ${relative_path}).patch"
	else
	    patch_name="patches/${relative_path}.patch"
	fi
        
        # 确保补丁文件的目录存在
        mkdir -p "$(dirname "$patch_name")"
        
        # 生成差异补丁
        echo "生成补丁: $relative_path"
        diff -urN "$a_file" "$b_file" > "$patch_name"
        
        # 检查补丁是否为空（无差异）
        if [[ ! -s "$patch_name" ]]; then
            echo "  无差异，删除空补丁"
            rm "$patch_name"
        else
            echo "  补丁已生成: $patch_name"
        fi
    else
        echo "警告: $A_DIR 中不存在对应文件: $relative_path"
    fi
done

echo "补丁生成完成！补丁文件保存在 patches/ 目录"
