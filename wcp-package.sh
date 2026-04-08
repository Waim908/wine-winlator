#!/bin/bash
if [[ $isArm64ec == 1 ]]; then
  isArm64ec="-arm64ec"
else
  isArm64ec=""
fi
create_json () {
if [[ -z $customDescription ]]; then
cat > '/tmp/output-wcp/tmp/profile.json' << EOF
{
  "type": "Wine",
  "versionName": "${wineVer}-wce-${isArm64ec:-amd64}",
  "versionCode": 1,
  "description": "${wineVer}-tkg-stg-ge${isArm64ec}. Built form [https://github.com/Waim908/wine-winlator]",
  "files": [],
  "wine": {
          "binPath": "bin",
          "libPath": "lib",
          "prefixPack": "prefixPack.txz"
  }
}
EOF
else
cat > '/tmp/output-wcp/tmp/profile.json' << EOF
{
  "type": "Wine",
  "versionName": "${wineVer}-wce-${isArm64ec:-amd64}",
  "versionCode": 1,
  "description": "${customDescription}",
  "files": [],
  "wine": {
          "binPath": "bin",
          "libPath": "lib",
          "prefixPack": "prefixPack.txz"
  }
}
EOF
fi
}
patchelf_fix() {
  LD_RPATH="/data/data/com.winlator/files/imagefs/usr/lib"
  LD_FILE=$LD_RPATH/ld-linux-aarch64.so.1
  find . -type f -exec file {} + | grep -E ":.*ELF" | cut -d: -f1 | while read -r elf_file; do
    echo "Patching $elf_file..."
    patchelf --set-rpath "$LD_RPATH" --set-interpreter "$LD_FILE" "$elf_file" || {
      echo "Failed to patch $elf_file" >&2
      continue
    }
  done
}
rm -rf /data/data/com.winlator/files/imagefs/home/xuser/.wine
rm -rf /tmp/output-wcp
rm -rf /data/data/com.winlator/files/imagefs/tmp
mkdir -p /data/data/com.winlator/files/imagefs/tmp/
mkdir -p /data/data/com.winlator/files/imagefs/home/xuser/.wine
if [[ -z $wineVer ]]; then
  if [[ ! -z $2 ]]; then
    wineVer="$2"
  else
    echo "声明wineVer变量"
    exit 1
  fi
fi
wineVer="${wineVer#wine-}"
export WINEESYNC=1
export WINEPREFIX=/data/data/com.winlator/files/imagefs/home/xuser/.wine
winePath=$1/bin
wineRoot=$1

if ! command -v zstd; then
  echo "zstd未安装"
  exit 1
fi
if ! command -v xz; then
  echo "xz未安装"
  exit 1
fi
if [[ -z $winePath ]]; then
  echo "没有在参数1定义wine可执路径"
  exit 1
else
  export USER=xuser
  unset DISPLAY
  if [[ $useBox64 == 1 ]]; then
      echo "使用box64执行"
      box64 $winePath/wineboot || exit 1
      sleep 3
      echo "Delete Registry Key: HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics"
      box64 $winePath/wine reg delete "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /f || exit 1
      sleep 3
  else
      $winePath/wineboot || exit 1
      sleep 3
      echo "Delete Registry Key: HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics"
      $winePath/wine reg delete "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /f || exit 1
      sleep 3
  fi
fi
if [[ $useBox64 == 1 ]]; then
  wine_version=$(box64 $winePath/wine --version)
else
  wine_version=$($winePath/wine --version)
fi
[[ $doNotCreateTXT == 1 ]] || {
cat > '/data/data/com.winlator/files/imagefs/home/xuser/.wine/drive_c/ProgramData/Microsoft/Windows/Start Menu/TkG-version.txt' << EOF
Version: $wine_version
Others:
  More staging settings in winecfg
  [Waim908/wine-winlator](https://github.com/Waim908/wine-winlator)
EOF
}
rm -rf $WINEPREFIX/dosdevices/*
# if [[ haveInclude == 1 ]]
timeStamp=$(TZ=Asia/Shanghai date +%s)
if [[ $useTimestamp == 1 ]]; then
  # 实际使用可能会强制替换为disable ，也就是说这个意义不大，仅作确认更新时间用
  echo $timeStamp > $WINEPREFIX/.update-timestamp
else
  # 这里参考了longjunyu的包，里面是disable
  echo "disable" > $WINEPREFIX/.update-timestamp
fi
cd $WINEPREFIX/..
rm -rf .wine/dosdevice/z:
mkdir -p /tmp/output-wcp/tmp
tar -I 'xz -T$(nproc) -9e' -cvf /tmp/output-wcp/tmp/prefixPack.txz .wine
cp -r -p $wineRoot/bin /tmp/output-wcp/tmp/
cp -r -p $wineRoot/lib /tmp/output-wcp/tmp/
cp -r -p $wineRoot/share /tmp/output-wcp/tmp/

cd /tmp/output-wcp/tmp/lib
find . -name "*.a" -type f -exec rm -v {} +

cd /tmp/output-wcp/tmp/
if [[ ! $doNotFixLibrary == 1 ]] &&  [[ ! -z $isArm64ec ]]; then
  command -v patchelf  || { echo "patchelf未安装" && exit 1;}
  patchelf_fix
fi
[[ $doNotCleanStaticLibrary == 1 ]] || {
  echo "Deleting static libraries..."
  find . -type f -name "*.a" -print0 | while IFS= read -r -d '' file; do
      echo "Deleting: $file"
      rm -f "$file" || { echo "Error: failed to delete $file" >&2; exit 1; }
  done
}
create_json
if [[ -z $customWcpName ]]; then
  tar -I 'zstd -T$(nproc) --ultra -22' -cvf /tmp/output-wcp/wine-$wineVer-wce${isArm64ec:-amd64}.wcp .
else
  tar -I 'zstd -T$(nproc) --ultra -22' -cvf /tmp/output-wcp/$customWcpName.wcp bin/ .
fi
echo "Output=> /tmp/output-wcp/wine-*.wcp"
