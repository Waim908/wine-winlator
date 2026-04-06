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

export ENABLE_PROTON_MF=1
bash -x /tmp/wine-winlator/set-tkg-cfg.sh wine-$wineVer /tmp/wine-tkg-git/wine-tkg-git/ || exit 1

bash +x /tmp/wine-winlator/add_patch.sh wine-glibc $wineVer /tmp/wine-tkg-git/wine-tkg-git/wine-tkg-userpatches/ || exit 1

echo "正在构建Wine-TKG..."
cd /tmp/wine-tkg-git/wine-tkg-git/
echo '_ci_build="true"' >>customization.cfg
yes | ./non-makepkg-build.sh || { cat /tmp/wine-tkg-git/wine-tkg-git/prepare.log && exit 1; }

echo "正在保存Ccache缓存..."
[[ -f /tmp/ccache.tar.xz ]] && rm -rf /tmp/ccache.tar.xz
cd ~/.cache
tar -I 'xz -T$(nproc) -9' -cf /tmp/ccache.tar.xz ccache

echo "正在打包Wine-TKG..."
wine_path=$(ls /tmp/output/ 2>/dev/null)
[[ -z $wine_path ]] && exit 1
bash -x /tmp/wine-winlator/wcp-package.sh /tmp/output/$wine_path $wineVer || exit 1
