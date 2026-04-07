# wine-winlator

# 本项目基于 [LGPL2.1](LICENSE)协议开源

winlator11 hostei mod wine  x86_64 补丁与releases

部分补丁请通过```get_file_9.2.sh```和```patch.sh```生成，其中大部分无效，可能导致编译错误

midi必须使用winlator版midimap.c！

# [关于部分wine问题的解决方法](#about)

# [如何编译Arm64ec?](#howToBuildArm64ec)

# Dir

原版

- *wine/* : 仅对wine10.15进行适配无法保证兼容性

Glibc 7.1.x

- *wine-glibc/* : 实验性通过LLM完善了补丁

- *wine-glibc-arm64ec/* : Arm64ec补丁

# Arm64ec Wine

**此版本只能在glibc环境的winlator运行！此仓库不负责编译bionic分支的版本！请勿用于bionic分支！**


# 鸣谢

 - [Frogging-Family/wine-tkg-git](https://github.com/Frogging-Family/wine-tkg-git)

 - [hostei/wine-tkg](https://github.com/hostei33/wine-tkg)

 - [brunodev85/wine-9.2-custom](https://github.com/brunodev85/wine-9.2-custom)

 - [longjunyu2/wine-custom](https://github.com/longjunyu2/wine-custom)

 - [AndreRH/wine](https://github.com/AndreRH/wine)

### termux 相关补丁

 - [Waim908/wine-termux](https://github.com/Waim908/wine-termux)

<a id ="howToBuildArm64ec"></a>

# 编译Arm64ec

### step 1

安装llvm-ming并定义$PATH

### step2

```cd /path/to/wine-src```

###  step3

```mkdir amd64 && cd amd64```

### step4

```source /path/to/comppile.conf amd64```

```bash
../configure --enable-win64  &&   make __tooldeps__ -j $(nproc)  && make -C nls -j $(nproc)
```

### step5

```cd ..```

```source /path/to/compile.conf arm64```

```bash
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
  CC=aarch64-linux-gnu-gcc
```

### step 6
```make -j4 && make install```

<a id="about"></a>

# 常见问题

Q：UnityH264解码问题？

A: 需要在你所使用的版本的rootfs进行修改添加gstreamer支持，具体在我的rootfs-custom-winlator仓库里面，不推荐直接替换rootfs.tzst，可能会出现一些问题。然后启用或添加环境变量```WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER```值为**1**

Q：10.15现在可以启动和渲染《甜蜜女友3》的画面，但是出现了鼠标无法点击的问题？

A：可以在设置里切换为跟手模式/触屏模式（不同修改版叫法可能不一样），原版对应在主界面左上角的设置->move cursor to touchpoint

Q: Winlator Glibc真的实现了标准posix shm吗？为什么ESYNC能直接用？

A: 尽管longjunyu开源的wine中定义了两种函数调用，普通文件系列（unlink open）与shm系列（shm_unlink shm_open），但是问题来了，如果真的实现了那么esync文件理论上不应该出现在tmp/，而是直接到/dev/shm（安卓不存在） ->  /dev/ashmem（安卓共享内存，但是实际上目前只实现到sysvshm标准而非posix标准）

Q: 我无法在winlator 7.1.5 启动此仓库发布的新版wine？

A: 你可以直接在box64官方仓库的工作流下载到最新的box64 wcp文件，安装后就能直接启动了。