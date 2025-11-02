#!/bin/bash
rm -rf /data/data/com.winlator/files/rootfs/home/xuser/.wine
rm -rf /tmp/output-whp
rm -rf /data/data/com.winlator/files/rootfs/tmp
mkdir -p /data/data/com.winlator/files/rootfs/tmp
mkdir -p /data/data/com.winlator/files/rootfs/home/xuser/.wine
if [[ -z $wineName ]]; then
  echo "你必须声明wineName变量"
  echo "格式必须为wine-开头，内容只能由数字和-组成"
  exit 1
fi
export WINEESYNC=1
export WINEFSYNC=1
export WINEPREFIX=/data/data/com.winlator/files/rootfs/home/xuser/.wine
export winePath=$1/bin
export wineRoot=$1
# need wineVer
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
  if [[ $useBox64 == 1 ]]; then
    echo "使用box64执行"
    if ! eval "box64 $winePath/wineboot"; then
      echo "失败"
      exit 1
    fi
  else
    if ! $winePath/wineboot; then
      echo "失败"
      exit 1
    fi
  fi
fi
rm -rf $WINEPREFIX/dosdevices/*
mkdir $WINEPREFIX/drive_x
echo "58000000" > $WINEPREFIX/drive_x/.windows-serial
# if [[ haveInclude == 1 ]]
timeStamp=$(TZ=Asia/Shanghai date +%s) 
if [[ ! $notTimestamp == 1 ]]; then
  echo $timeStamp > $WINEPREFIX/.update-timestamp
else
  echo "disable" > $WINEPREFIX/.update-timestamp
fi
cd $WINEPREFIX/..
mkdir -p /tmp/output-whp
tar -I 'zstd -T$(nproc)' -cvf /tmp/output-whp/container-pattern-$wineName.tzst .wine
cp -r -p $wineRoot /tmp/output-whp/
baseName=$(basename $wineRoot)
if [[ ! haveInclude == 1 ]]; then
  rm -rf /tmp/output-whp/$baseName/include
fi
cd /tmp/output-whp/
mv $baseName $wineName-
tar -I 'xz -T$(nproc)' -cvf /tmp/output-whp/$wineName.whp $wineName container-pattern-$wineName.tzst
echo "Output=> /tmp/output-whp/$wineName.whp"