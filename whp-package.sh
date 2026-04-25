#!/bin/bash
rm -rf /data/data/com.winlator/files/rootfs/home/xuser/.wine
rm -rf /tmp/output-whp
rm -rf /data/data/com.winlator/files/rootfs/tmp
mkdir -p /data/data/com.winlator/files/rootfs/tmp/shm
mkdir -p /data/data/com.winlator/files/rootfs/home/xuser/.wine
if [[ -z $wineVer ]]; then
  echo "你必须声明wineVer参数"
  echo "内容只能由数字或小数和-组成"
  exit 1
fi
[[ -z $1 ]] && echo "请指定wine可执行文件路径" && exit 1
export WINEESYNC=1
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
      box64 $winePath/wineboot || exit 1
      box64 $winePath/wineserver -w || exit 1
      echo "删除注册表: HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics"
      box64 $winePath/wine reg delete "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /f || exit
      box64 $winePath/wineserver -w || exit 1
  else
      $winePath/wineboot || exit 1
      $winePath/wineserver -w || exit 1
      echo "删除注册表: HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics"
      $winePath/wine reg delete "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /f || exit
      $winePath/wineserver -w || exit 1
  fi
  sleep 3
  exit_status=$?
  if [[ $exit_status -eq 0 ]]; then
      echo "wineboot 执行成功"
  else
      echo "wineboot 执行失败，退出码: $exit_status"
      # 这里可以添加失败处理逻辑
      exit 1
  fi
fi
sleep 2
if [[ $useBox64 == 1 ]]; then
  wine_version=$(box64 $winePath/wine --version)
else
  wine_version=$($winePath/wine --version)
fi
cat > '/data/data/com.winlator/files/rootfs/home/xuser/.wine/drive_c/ProgramData/Microsoft/Windows/Start Menu/wine_version.txt' << EOF
Version: $wine_version
[Waim908/wine-winlator](https://github.com/Waim908/wine-winlator)
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

if [[ -z $memLimit]]; then
memLimit=$(free -h | awk 'NR==2{
    val=$7; gsub(/[a-zA-Z]/,"",val);
    unit=$7; gsub(/[0-9.]/,"",unit);
    if(unit~/^G/) mem=val*1024;
    else if(unit~/^M/) mem=val;
    else mem=val/1024;
    print int(mem*0.5)"M"
}')
fi
[[ -z $memLimit ]] && memLimit="512M"
echo "压缩时内存限制为([物理内存整数G]x0.5): $memLimit"
echo "可以自定义\$memLimit变量提高上限"

tar -I 'zstd -T$(nproc) --ultra -22 -M$memLimit' -cvf /tmp/output-whp/container-pattern-$wineVer.tzst .wine
cp -r -p $wineRoot /tmp/output-whp/
baseName=$(basename $wineRoot)
if [[ ! haveInclude == 1 ]]; then
  rm -rf /tmp/output-whp/$baseName/include
fi
cd /tmp/output-whp/
mv $baseName wine-$wineVer-
tar -I 'xz -T$(nproc) -9e -M $memLimit' -cvf /tmp/output-whp/wine-$wineVer.whp wine-$wineVer- container-pattern-$wineVer.tzst
echo "Output=> /tmp/output-whp/wine-$wineVer.whp"