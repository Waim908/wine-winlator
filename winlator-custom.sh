export DEBIAN_FRONTEND=noninteractive
if [[ -f /tmp/wineVer.conf ]]; then
  source /tmp/wineVer.conf
  echo "wineVer: $wineVer"
else
  echo "没有wineVer.conf文件，退出！"
  exit 1
fi
apt clean
chmod 777 /tmp
apt update
apt install -y patch xz-utils sudo ccache zstd || exit 1
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
export LC_ALL=en_US.UTF-8

git clone --depth=1 https://github.com/brunodev85/wine-${wineVer}-custom.git wine-src

cd wine-src

bash +x /tmp/wine-winlator/apply_patch.patch wine-winlator-custom $wineVer || ${ echo 补丁应用失败 && exit 1;}

echo "正在构建Wine..."

source /tmp/wine-winlator/compile.conf amd64

./configure --prefix=/tmp/output/wine-10.10 --enable-archs="i386,x86_64" --disable-win16 --disable-tests --without-capi --without-coreaudio --without-cups --without-gphoto --without-osmesa --without-oss --without-pcap --without-pcsclite --without-sane --without-udev --without-unwind --without-usb --without-v4l2 --without-wayland --without-xinerama --without-piper --without-ffmpeg || { echo "构建失败" && exit 1; }

make -j`nproc` || { echo 编译失败 && exit 1;}

make install

echo "正在保存Ccache缓存..."
[[ -f /tmp/ccache.tar.xz ]] && rm -rf /tmp/ccache.tar.xz
cd ~/.cache
tar -I 'xz -T$(nproc) -9' -cf /tmp/ccache.tar.xz ccache

echo "正在打包Wine..."
wine_path=$(ls /tmp/output/ 2>/dev/null)
[[ -z $wine_path ]] && exit 1
bash -x /tmp/wine-winlator/whp-package.sh /tmp/output/$wine_path $wineVer || exit 1
