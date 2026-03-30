#!/bin/bash

script_dir="$(dirname $(readlink -f "$0"))"
source "$script_dir/$1/$2/__patch__.conf"

echo "${_patch_file_[@]}"

for i in "${_patch_file_[@]}"; do
  cp -r "$script_dir/$1/$2/$i" "$3"
done

cd "$3" || exit 1

# --- 替换开始 ---
# 原命令: mmv "*.patch" "#1.mylatepatch"
for f in *.patch; do
  [ -e "$f" ] || continue
  mv -- "$f" "${f%.patch}.mylatepatch"
done
# --- 替换结束 ---