#!/bin/bash

script_dir="$(dirname $(readlink -f "$0"))"
source "$script_dir/$1/$2/__patch__.conf"

echo "${_patch_file_[@]}"

if [[ -z $3 ]]; then
  cd $(pwd) || exit 1
else
  cd $3 || exit 1
fi

[[ -z $patch_dir ]] && patch_dir="$script_dir/$1/$2"

if [[ $dryRun == 1 ]]; then
  for i in "${_patch_file_[@]}"; do
    echo "测试补丁： $i"
    [[ -f "$patch_dir/$i" ]] || { echo "补丁不存在!" && exit 1;}
    patch --dry-run -p1 < "$script_dir/$1/$2/$i" || { echo "补丁测试失败!可能存在补丁先后性问题,测试结果仅供参考";}
  done
else
  for i in "${_patch_file_[@]}"; do
    echo "应用补丁： $i"
    [[ -f "$patch_dir/$i" ]] || { echo "补丁不存在!" && exit 1;}
    patch --no-backup-if-mismatch -N -p1 < "$script_dir/$1/$2/$i" || { echo "补丁应用失败!" && exit 1;}
  done
fi
cd -