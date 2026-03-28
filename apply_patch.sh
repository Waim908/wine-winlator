#!/bin/bash

script_dir="$(dirname $(readlink -f "$0"))"
source "$script_dir/$1/$2/__patch__.conf"

echo "${_patch_file_[@]}"

cd $3 || exit 1

for i in "${_patch_file_[@]}"; do
  echo "应用补丁： $i"
  patch -p1 < "$script_dir/$1/$2/$i" || exit 1
done
cd -

