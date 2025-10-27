mkdir -p download/dlls/midimap/
mkdir -p download/dlls/winex11.drv
mkdir -p download/dlls/xinput1_3
cd download/dlls/midimap
wget https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/midimap/midimap.c
echo "dlls/midi/"
cd ../winex11.drv
wget https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/winex11.drv/keyboard.c
wget https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/winex11.drv/vulkan.c
wget https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/winex11.drv/window.c
wget https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/winex11.drv/x11drv.h
wget  https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/winex11.drv/x11drv_main.c
echo "dlls/winex11.drv/"
cd ../xinput1_3
wget  https://raw.githubusercontent.com/brunodev85/wine-9.2-custom/main/dlls/xinput1_3/main.c
echo "dlls/xinput1_3/"


cd ../../
