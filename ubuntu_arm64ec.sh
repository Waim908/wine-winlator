[[ -d /tmp/llvm_mingw ]] || { echo "无法找到编译器目录" && exit 1;}
export PATH=/tmp/llvm_mingw/bin:$PATH
export LC_ALL=en_US.UTF-8

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
apt install -y patch xz-utils || exit 1

cd /tmp/wine-src

echo "Patch Ver=> $wineVer"

bash -x /tmp/wine-winlator/apply_patch.sh wine-glibc-arm64ec $wineVer || exit 1
source /tmp/wine-winlator/compile.conf amd64
mkdir amd64
cd amd64
../configure --enable-win64 || { cat config.log && exit 1;}
make __tooldeps__ -j $(nproc) || exit 1
make -C nls -j $(nproc) || exit 1
cd ..
source /tmp/wine-winlator/compile.conf arm64

[[ $makeWineVK == 1 ]] && dlls/winevulkan/make_vulkan

./configure --prefix=/tmp/wine_build \
  --with-mingw=clang \
  --enable-archs=arm64ec,aarch64,i386 \
  --enable-tools \
  --disable-tests \
  --host=aarch64-linux-gnu \
  host_alias=aarch64-linux-gnu \
  build_alias=x86_64-linux-gnu \
  --with-wine-tools=amd64 \
  --disable-win16 --disable-tests --without-capi --without-coreaudio --without-cups --without-gphoto --without-osmesa --without-oss --without-pcap --without-pcsclite --without-sane --without-udev --without-unwind --without-usb --without-v4l2 --without-wayland --without-xinerama --without-piper \
  CC=aarch64-linux-gnu-gcc || { cat config.log && exit 1;}

make -j $(nproc) || exit 1
make install || exit 1
cd /tmp
tar -I "xz -T$(nproc) -9e" -cvf /tmp/build_arm64ec_wine.tar.xz wine_build || exit 1
