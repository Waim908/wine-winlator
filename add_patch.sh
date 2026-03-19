script_dir="$(dirname $(readlink -f "$0"))"
source "$script_dir/$1/$2/__patch__.conf"
echo ${_patch_file_[@]}
for i in ${_patch_file_[@]}; do
  ls "$script_dir/$1/$2/"$i
  cp "$script_dir/$1/$2/"$i $3
done
cd $3
mmv "*.patch" "#1.mylatepatch"