call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
cl /c /EHsc all.c
ar r manymouse.a all.obj