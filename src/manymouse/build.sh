mkdir linux
cd linux
g++ -c ../linux_evdev.c  ../x11_xinput2.c ../manymouse.c ../windows_wminput.c ../macosx_hidmanager.c ../macosx_hidutilities.c
ar r manymouse.a linux_evdev.o x11_xinput2.o manymouse.o windows_wminput.o macosx_hidmanager.o macosx_hidutilities.o
