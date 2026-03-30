#!/bin/bash

script_dir="$(dirname $(readlink -f "$0"))"
source "$script_dir/$1/$2/__patch__.conf"

echo "${_patch_file_[@]}"

cd $3 || exit 1

for i in "${_patch_file_[@]}"; do
  echo "应用补丁： $i"
  [[ -f "$script_dir/$1/$2/$i" ]] || { echo "补丁不存在!" && exit 1;}
  patch -p1 < "$script_dir/$1/$2/$i" || { echo "补丁应用失败!" && exit 1;}
done
cd -

