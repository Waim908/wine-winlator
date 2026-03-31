#!/bin/bash
info() {
  echo -e "\e[36m\e[1mINFO: \e[36m${1}\e[0m"
}
# yellow
err() {
  echo -e "\e[33m\e[1mERROR: \e[33m${1}\e[0m"
}
# red
warn() {
  echo -e "\e[31m\e[1mWARN: \e[31m${1}\e[0m"
}

script_dir="$(dirname $(readlink -f "$0"))"
source "$script_dir/config/custom.cfg" || { warn "配置文件加载失败: $script_dir/config.cfg" && exit 1; }

arch=$(uname -m)
[[ ! $arch == x86_64 ]] && { warn "不支持的系统架构" && exit 1; }

_install_deps() {
  [[ $DEBIAN_FRONTEND == noninteractive ]] && info "软件包安装过程Cli交互式过程已关闭"
  local i
  local failed_pkgs=()
  local yn
  for i in ${deps[@]}; do
    dpkg -s $i 2>&1 >/dev/null && info "已安装=> $i" || { _apt_exec $i || { err "$i安装失败,跳过!" && failed_pkgs+=($i); }; }
  done
  echo -e "\n"
  [[ ${#failed_pkg[@]} == 0 ]] && info "没有失败的依赖" || {
    echo -e "以下软件包安装失败了:\n"
    echo "${failed_pkgs[@]}"
    read -p "是否继续(y/n)?" yn || { [[ $yn == y ]] && return 0 || return 1; }
  }
}

_repo_menu() {
  local i
  if [[ -z $_targetArm64ecRepo ]]; then
    select i in ${_arm64ecRepos[@]}; do
      _targetArm64ecRepo="$i"
      break
    done
  fi
}

_build_wine_arm64ec() {
  echo 1
}

_main_menu() {
  cat >/dev/tty <<EOF
############################
#Winlator Wine Build System#
############################
Arm64ec Ver
1) wine_arm64ec
*) exit
EOF
  read -p "输入序号开始:" _targetBuild
}
[[ -z $_targetBuild ]] && _main_menu

info "构建目标：$_targetBuild"

if [[ $_doNotInstallDep == true ]]; then
  info "跳过依赖安装"
else
  distro=$(source /etc/os-release && echo $ID)
  [[ -z $distro ]] && {
    warn "无法从/etc/os-release获取发行版数据"
    exit 1
  }
  case $distro in
  ubuntu)
    deps=("${_ubuntuArm64ecDeps[@]}")
    _install_deps
    ;;
  *)
    warn "不支持的发行版ID:$distro"
    ;;
  esac
fi

mkdir -p /tmp/wlt-wine/
rm -rf /tmp/wlt-wine/wine-src/
mkdir -p "$_outputPath"

src_dir=""
[[ ! -z $_localSrcPath ]] && {
  cd "$(dirname "$_localSrcPath")" || { warn "本地源码路径无效:$_localSrcPath" && exit 1; }
  mkdir "/tmp/wlt-wine/"
  cp -r -p * "/tmp/wlt-wine/$(basename $_localSrcPath)/"
  src_dir="/tmp/wlt-wine/wine-src"
  cd $script_dir
}

case $_targetBuild in
wine_arm64ec)
  [[ -z $src_dir ]] && {
    [[ -z $_targetArm64ecRepo ]] && _repo_menu
    cd /tmp/wlt-wine
    if [[ -z $_targetBranch ]]; then
      git clone --depth=1 $_targetArm64ecRepo wine-src || { warn "克隆仓库失败了!" && exit 1; }
    else
      git clone --depth=1 -b $_targetBranch $_targetArm64ecRepo wine-src || { warn "克隆仓库失败了!" && exit 1; }
    fi
  }

  [[ -z $_targetPatchVer ]] && {
    _targetPatchVer=$(cat VERSION)
  }

  [[ $_applyPatch == true ]] && {
    "$script_dir"/apply_patch.sh "wine-glibc-arm64ec" $_targetPatchVer
  }

  cd $src_dir
  mkdir amd64
  cd amd64
  info "构建wine tools..."
  ../configure --enable-win64 || { warn "失败!" && cat config.log && exit 1; }
  make __tooldeps__ -j $(nproc) && make -C nls -j $(nproc)
  cd ..
  info "构建arm64ec..."
  ./configure --prefix="$_outputPath" \
    ${_arm64ecConfigureArgs[@]} || { warn "失败" && cat config.log && exit 1; }

  info "编译arm64ec"
  make -j$(nproc) >/tmp/wlt-wine/make.log 2>&1 || { warn "编译失败!日志:/tmp/wlt-wine/make.log" && exit 1; }

  info "安装到$_outputPath"
  make install && info "完成! Output=> $_outputPath"
  ;;
esac
