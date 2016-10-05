#!/usr/bin/env sh

uname_string=`uname | sed 'y/LINUXDARWINFREEOPENPCBSDMSYS/linuxdarwinfreeopenpcbsdmsys/'`
host_arch=`uname -m | sed 'y/XI/xi/'`
case "$uname_string" in
  *linux*)
    HOST_NATIVE="$host_arch"-linux-gnu
    JOBS="-j`grep ^processor /proc/cpuinfo|wc -l`"
    ;;
  *freebsd*)
    HOST_NATIVE="$host_arch"-freebsd
    JOBS="-j`sysctl kern.smp.cpus | sed 's/kern.smp.cpus: //'`"
    ;;
  *darwin*)
    HOST_NATIVE=x86_64-apple-darwin10
    JOBS="-j1"
    ;;
  *msys*)
    HOST_NATIVE="$host_arch"-w64-mingw32
    JOBS="-j4"
    ;;
  *)
    echo "Unsupported build system : `uname`"
    exit 1
    ;;
esac
HOST_TARGET=arm-vita-eabi

LIBICONV_VERSION=1.14
GMP_VERSION=6.1.1
MPFR_VERSION=3.1.4
MPC_VERSION=1.0.3
ISL_VERSION=0.17.1
ZLIB_VERSION=1.2.8
LIBZIP_VERSION=1.1.3
LIBELF_VERSION=0.8.13
JANSSON_VERSION=2.8
DLFCN_VERSION=1.0.0
BINUTILS_VERSION=2.27
GCC_VERSION=6.2.0

ROOTDIR=$(realpath `dirname $0`)
PATCHDIR=${ROOTDIR}/patch
DOWNLOADDIR=${ROOTDIR}/download
SRCDIR=${ROOTDIR}/src
BUILDDIR=${ROOTDIR}/build
mkdir -p ${SRCDIR} ${BUILDDIR}
SRCRELDIR=$(realpath --relative-to="${BUILDDIR}" ${SRCDIR})
INSTALLDIR=${ROOTDIR}/install
VITASDKROOT=${ROOTDIR}/vitasdk
