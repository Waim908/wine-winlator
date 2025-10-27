# wine-winlator
winlator11 hostei mod wine  x86_64 补丁与releases

## 部分补丁请通过```get_file_9.2.sh```和```patch.sh```生成

# proton wine

## 由于proton在xinput与dinput的joy sdl控制器修改与winlator wine 9.2的dinput和xinput产生冲突，除了修复dinput和xinput之外，你还需要使winebus.sys同步mainline stable版本（实在不行直接复制wine10.10原版wine的xinput与dinput库以及winebus.sys=>system32/drivers）

# 此项目维护相对困难，其次winlator原作者并未开源wine10.10无法制作对应补丁，故可能存在兼容性问题

# 本项目基于 [LGPL2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)协议开源

# 鸣谢
 - [Frogging-Family/wine-tkg-git](https://github.com/Frogging-Family/wine-tkg-git)
 - [hostei/wine-tkg](https://github.com/hostei33/wine-tkg)
 - [brunodev85/wine-9.2-custom](https://github.com/brunodev85/wine-9.2-custom)