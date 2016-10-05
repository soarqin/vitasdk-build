Build for Linux
===============
1. Install following packages: make, gcc, g++, pkg-config, texinfo, bison, flex, cmake
2. Run ./build.sh

Build for MinGW
===============
1. Get latest msys2 from https://sourceforge.net/projects/msys2 and install it somewhere.
2. Run 'pacman -Syu' and follow instruction to restart msys2 shell, run it again to update everything to latest.
3. Run 'pacman -S --needed base git make texinfo bison flex tar gzip bzip2 xz patch diffutils mingw-w64-i686-toolchain mingw-w64-i686-cmake' to install required packages for VitaSDK building.
4. (Optional) For building 3rd party libs like vita_portlibs, vita libs for EasyRPG and etc, you had better install other packages: autoconf, automake, pkgconfig, libtool
5. Start msys2 shell by executing "mingw32.exe"
6. Run ./build.sh

Note
====
If you need step builds, just use ./build.sh --help to see which steps are supported.
