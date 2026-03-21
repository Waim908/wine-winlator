apt update
yes | apt install build-essential locales git patch xz-utils
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
export LANG=en_US.UTF-8

export ENABLE_PROTON_MF=1
bash -x /tmp/wine-winlator/set-tkg-cfg.sh wine-$wineVer /tmp/wine-tkg-git/wine-tkg-git/

bash +x /tmp/wine-winlator/add_patch.sh wine-glibc $wineVer /tmp/wine-tkg-git/wine-tkg-git/wine-tkg-userpatches/

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
sudo bash -x /tmp/wine-winlator/wcp-package.sh /tmp/output/$wine_path $wineVer || exit 1
