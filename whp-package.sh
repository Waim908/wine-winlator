#!/bin/bash
rm -rf /data/data/com.winlator/files/rootfs/home/xuser/.wine
rm -rf /tmp/output-whp
rm -rf /data/data/com.winlator/files/rootfs/tmp
mkdir -p /data/data/com.winlator/files/rootfs/tmp/shm
mkdir -p /data/data/com.winlator/files/rootfs/home/xuser/.wine
if [[ -z $wineVer ]]; then
  echo "你必须声明wineVer变量"
  echo "内容只能由数字或小数和-组成"
  exit 1
fi
export WINEESYNC=1
export WINEFSYNC=1
export WINEPREFIX=/data/data/com.winlator/files/rootfs/home/xuser/.wine
export winePath=$1/bin
export wineRoot=$1
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
    if ! box64 $winePath/wineboot 2>&1 >/dev/tty &; then
      echo "失败"
      exit 1
    fi
  else
    if ! $winePath/wineboot 2>&1 >/dev/tty &; then
      echo "失败"
      exit 1
    fi
  fi
fi
wait
if [[ $useBox64 == 1 ]]; then
  wineVersion=$(box64 $winePath/wine --version)
else
  wineVersion=$($winePath/wine --version)
fi
cat > '$WINEPREFIX/drive_c/ProgramData/Microsoft/Windows/Start Menu/TkG-version.bat' << 'EOF'
winver
echo "Wine Version: ${wineVersion}"
echo "More staging settings in winecfg"
echo "[Waim908/wine-winlator](https://github.com/Waim908/wine-winlator)"
EOF
rm -rf $WINEPREFIX/dosdevices/*
mkdir $WINEPREFIX/drive_x
echo "58000000" > $WINEPREFIX/drive_x/.windows-serial
# if [[ haveInclude == 1 ]]
timeStamp=$(TZ=Asia/Shanghai date +%s)
if [[ ! $notTimestamp == 1 ]]; then
  # 实际使用可能会强制替换为disable ，也就是说这个意义不大，仅作确认更新时间用
  echo $timeStamp > $WINEPREFIX/.update-timestamp
else
  echo "disable" > $WINEPREFIX/.update-timestamp
fi
cd $WINEPREFIX/..
mkdir -p /tmp/output-whp
tar -I 'zstd -T$(nproc)' -cvf /tmp/output-whp/container-pattern-$wineVer.tzst .wine
cp -r -p $wineRoot /tmp/output-whp/
baseName=$(basename $wineRoot)
if [[ ! haveInclude == 1 ]]; then
  rm -rf /tmp/output-whp/$baseName/include
fi
cd /tmp/output-whp/
mv $baseName wine-$wineVer-
tar -I 'xz -T$(nproc)' -cvf /tmp/output-whp/wine-$wineVer.whp wine-$wineVer- container-pattern-$wineVer.tzst
echo "Output=> /tmp/output-whp/wine-$wineVer.whp"