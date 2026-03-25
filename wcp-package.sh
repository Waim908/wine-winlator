#!/bin/bash
[[ isArm64ec == 1 ]] && isArm64ec="-arm64ec" || isArm64ec=""
create_json () {
if [[ -z $customDescription ]]; then
cat > '/tmp/output-wcp/tmp/profile.json' << EOF
{
  "type": "Wine",
  "versionName": "${wineVer}-custom${isArm64ec}",
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
  "versionName": "${wineVer}",
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
claen_static_library () {
  find . -type f -name "*.a" -exec rm -f {} \;
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
  if [[ $useBox64 == 1 ]]; then
      echo "使用box64执行"
      box64 $winePath/wineboot || exit 1
#      box64 $winePath/wine cmd /c "reg import " /f"
  else
      $winePath/wineboot || exit 1
  fi
  sleep 3
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
tar -I 'xz -T$(nproc) -9' -cvf /tmp/output-wcp/tmp/prefixPack.txz .wine
cp -r -p $wineRoot/bin /tmp/output-wcp/tmp/
cp -r -p $wineRoot/lib /tmp/output-wcp/tmp/
cp -r -p $wineRoot/share /tmp/output-wcp/tmp/
cd /tmp/output-wcp/tmp/lib
[[ $doNotCleanStaticLibrary == 1 ]] || clean_static_library
cd /tmp/output-wcp/tmp/
create_json
if [[ -z $customWcpName ]]; then
  tar -I 'zstd -T$(nproc) --ultra -19' -cvf /tmp/output-wcp/wine-$wineVer${isArm64ec}.wcp .
else
  tar -I 'zstd -T$(nproc) --ultra -19' -cvf /tmp/output-wcp/$customWcpName.wcp bin/ .
fi
echo "Output=> /tmp/output-wcp/wine-$wineVer${isArm64ec}.wcp"
