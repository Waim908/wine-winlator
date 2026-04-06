file_path=$2
sed2() {
  local key="$1"
  local value="$2"

  if [[ -f "$file_path2" ]]; then
    sed -i "s|^${key}=\"[^\"]*\"|${key}=\"${value}\"|" "$file" || exit 1
  else
    echo "File not found: $file"
    exit 1
  fi
}

if [[ $1 =~ wine-([0-9]+)\.([0-9]+) ]]; then
  main_ver="${BASH_REMATCH[1]}"
  sub_ver="${BASH_REMATCH[2]}"
else
  echo "Illegal version number"
  exit 1
fi

file_path2="$file_path/customization.cfg"
sed2 _use_staging true
sed2 _staging_version "v$(echo $1 | sed 's/^wine-//')"
if (( main_ver < 10 || (main_ver == 10 && sub_ver <= 16) )); then
  echo "Have esync & fsync ✅"
  sed2 _use_esync true
  sed2 _use_fsync true
else
  echo "No esync & fsync ❌"
  sed2 _use_esync false
  sed2 _use_fsync false
fi

sed2 _GE_WAYLAND false
sed2 _plain_version $1
sed2 _staging_version "v$(echo $1 | sed 's/^wine-//')"
sed2 _wayland_driver false
sed2 _proton_battleye_support false
sed2 _proton_eac_support false
sed2 _mk11_fix false
sed2 _proton_fs_hack true
#10.16+不支持！！！
[[ $ENABLE_PROTON_MF == 1 ]] && ENABLE_PROTON_MF=true
[[ $ENABLE_PROTON_MF == true ]] && {
  if [[ $main_ver -lt 10 ]] || [[ $main_ver -eq 10 && $sub_ver -le 16 ]]; then
    sed2 _proton_winevulkan true
    sed2 _proton_mf_patches true
  else
    echo "Version > 10.16, setting _proton_winevulkan and _proton_mf_patches to false"
    sed2 _proton_winevulkan false
    sed2 _proton_mf_patches false
  fi
}
sed2 _msvcrt_nativebuiltin true
sed2 _win10_default true
sed2 _community_patches_auto_update true
sed2 _nomakepkg_prefix_path /tmp/output

file_path2="$file_path/wine-tkg-profiles/advanced-customization.cfg"
sed2 _GCC_FLAGS "-O3 -pipe -msse3 -mfpmath=sse -ftree-vectorize -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
sed2 _LD_FLAGS "-s -Wl,-O3,--sort-common,--as-needed"
sed2 _CROSS_FLAGS "-O3 -pipe -msse3 -mfpmath=sse -ftree-vectorize -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
sed2 _CROSS_LD_FLAGS "-s -Wl,-O3,--sort-common,--as-needed"
sed2 _NOLIB32 wow64
sed2 _configure_userargs64 "--disable-win16 --disable-tests --without-capi --without-coreaudio --without-cups --without-gphoto --without-osmesa --without-oss --without-pcap --without-pcsclite --without-sane --without-udev --without-unwind --without-usb --without-v4l2 --without-wayland --without-xinerama --without-piper"
sed2 _user_patches_no_confirm true

[[ $NO_COMPILE == 1 ]] && NO_COMPILE=true
if [[ $NO_COMPILE == true ]]; then
  sed2 _NOCOMPILE "true"
  echo "NO_COMPILE is set to true, will not compile Wine-TKG 🔴"
else
  sed2 _NOCOMPILE "false"
  echo "NO_COMPILE is set to false, will compile Wine-TKG 🟢"
fi

echo "TkG Configuration file setting completed!"
