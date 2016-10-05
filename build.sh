#!/usr/bin/env sh

set -e
set -o pipefail

if [ $# -gt 0 ]; then
  while test $# -gt 0
  do
    case "$1" in
      --help) echo "Supported steps: gcc-deps toolchain-deps toolchain binutils gcc headers newlib pthread gcc-final strip"
        exit 1
        ;;
      gcc-deps) STEP_GCC_DEPS=true
        ;;
      toolchain-deps) STEP_TOOLCHAIN_DEPS=true
        ;;
      toolchain) STEP_TOOLCHAIN=true
        ;;
      binutils) STEP_BINUTILS=true
        ;;
      gcc) STEP_GCC_FIRST=true
        ;;
      headers) STEP_HEADERS=true
        ;;
      newlib) STEP_NEWLIB=true
        ;;
      pthread) STEP_PTHREAD=true
        ;;
      gcc-final) STEP_GCC_FINAL=true
        ;;
      strip) STEP_STRIP=true
        ;;
      *) echo "Unsupported $1"
        exit 1
        ;;
    esac
    shift
  done
else
  STEP_ALL=true
fi

. ./build-common.sh

mkdir -p ${DOWNLOADDIR} ${SRCDIR} ${BUILDDIR} ${INSTALLDIR}

function do_download {
  filename=$2
  if [ "${filename}" == "" ]; then
      filename=$(basename "$1")
  fi
  if [ ! -d ${SRCDIR}/${filename%%.[a-zA-Z\.]*} ]; then
    downloaded=true
    curl -L ${1} > ${DOWNLOADDIR}/${filename}
    case ${filename##*.} in
      xz) tar xJf ${DOWNLOADDIR}/${filename} -C ${SRCDIR}
        ;;
      bz2) tar xjf ${DOWNLOADDIR}/${filename} -C ${SRCDIR}
        ;;
      gz) tar xzf ${DOWNLOADDIR}/${filename} -C ${SRCDIR}
        ;;
      *) tar xaf ${DOWNLOADDIR}/${filename} -C ${SRCDIR}
        ;;
    esac
  else
    downloaded=false
  fi
}

if [[ ${STEP_ALL} = true || ${STEP_GCC_DEPS} = true ]]; then
  echo "[Step 1.1] Build libiconv..."
  do_download http://ftp.gnu.org/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz
  if [ ${downloaded} = true ]; then
    cd ${SRCDIR}/libiconv-${LIBICONV_VERSION}
    patch -p1 < ${PATCHDIR}/libiconv.patch
  fi
  rm -rf ${BUILDDIR}/libiconv-${LIBICONV_VERSION}
  mkdir -p ${BUILDDIR}/libiconv-${LIBICONV_VERSION}
  cd ${BUILDDIR}/libiconv-${LIBICONV_VERSION}
  ../${SRCRELDIR}/libiconv-${LIBICONV_VERSION}/configure --build=${HOST_NATIVE} --host=${HOST_NATIVE} --prefix=${INSTALLDIR} --disable-shared --disable-nls
  make ${JOBS}
  make install

  echo "[Step 1.2] Build GMP..."
  cd ${DOWNLOADDIR}
  do_download http://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz
  rm -rf ${BUILDDIR}/gmp-${GMP_VERSION}
  mkdir -p ${BUILDDIR}/gmp-${GMP_VERSION}
  cd ${BUILDDIR}/gmp-${GMP_VERSION}
  ../${SRCRELDIR}/gmp-${GMP_VERSION}/configure --build=${HOST_NATIVE} --host=${HOST_NATIVE} --prefix=${INSTALLDIR} --disable-shared --enable-cxx
  make ${JOBS}
  make install

  echo "[Step 1.3] Build MPFR..."
  do_download http://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz
  rm -rf ${BUILDDIR}/mpfr-${MPFR_VERSION}
  mkdir -p ${BUILDDIR}/mpfr-${MPFR_VERSION}
  cd ${BUILDDIR}/mpfr-${MPFR_VERSION}
  ../${SRCRELDIR}/mpfr-${MPFR_VERSION}/configure --build=${HOST_NATIVE} --host=${HOST_NATIVE} --prefix=${INSTALLDIR} --disable-shared --with-gmp=${INSTALLDIR}
  make ${JOBS}
  make install

  echo "[Step 1.4] Build MPC..."
  do_download http://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
  rm -rf ${BUILDDIR}/mpc-${MPC_VERSION}
  mkdir -p ${BUILDDIR}/mpc-${MPC_VERSION}
  cd ${BUILDDIR}/mpc-${MPC_VERSION}
  ../${SRCRELDIR}/mpc-${MPC_VERSION}/configure --build=${HOST_NATIVE} --host=${HOST_NATIVE} --prefix=${INSTALLDIR} --disable-shared --with-gmp=${INSTALLDIR} --with-mpfr=${INSTALLDIR}
  make ${JOBS}
  make install

  echo "[Step 1.5] Build ISL..."
  do_download http://isl.gforge.inria.fr/isl-${ISL_VERSION}.tar.xz
  rm -rf ${BUILDDIR}/isl-${ISL_VERSION}
  mkdir -p ${BUILDDIR}/isl-${ISL_VERSION}
  cd ${BUILDDIR}/isl-${ISL_VERSION}
  ../${SRCRELDIR}/isl-${ISL_VERSION}/configure --build=${HOST_NATIVE} --host=${HOST_NATIVE} --prefix=${INSTALLDIR} --disable-shared --with-gmp-prefix=${INSTALLDIR}
  make ${JOBS}
  make install
fi

if [[ ${STEP_ALL} = true || ${STEP_TOOLCHAIN_DEPS} = true ]]; then
  echo "[Step 2.1] Build zlib..."
  do_download http://zlib.net/zlib-${ZLIB_VERSION}.tar.xz
  cd ${SRCDIR}/zlib-${ZLIB_VERSION}
  if [[ "${HOST_NATIVE}" == *"mingw"* ]]; then
    make -f win32/Makefile.gcc clean
    BINARY_PATH=${INSTALLDIR}/bin INCLUDE_PATH=${INSTALLDIR}/include LIBRARY_PATH=${INSTALLDIR}/lib make -f win32/Makefile.gcc clean install
  else
    ./configure --prefix=${INSTALLDIR}
    make clean
    make ${JOBS} install
  fi

  echo "[Step 2.2] Build libzip..."
  do_download https://nih.at/libzip/libzip-${LIBZIP_VERSION}.tar.xz
  rm -rf ${BUILDDIR}/libzip-${LIBZIP_VERSION}
  mkdir -p ${BUILDDIR}/libzip-${LIBZIP_VERSION}
  cd ${BUILDDIR}/libzip-${LIBZIP_VERSION}
  CFLAGS='-DZIP_STATIC' ${SRCDIR}/libzip-${LIBZIP_VERSION}/configure --host=${HOST_NATIVE} --prefix=$INSTALLDIR --disable-shared --enable-static
  make ${JOBS} -C lib install

  echo "[Step 2.3] Build libelf..."
  do_download http://www.mr511.de/software/libelf-${LIBELF_VERSION}.tar.gz
  if [ ${downloaded} = true ]; then
    cd ${SRCDIR}/libelf-${LIBELF_VERSION}
    patch -p1 < ${PATCHDIR}/libelf.patch
  fi
  rm -rf ${BUILDDIR}/libelf-${LIBELF_VERSION}
  mkdir -p ${BUILDDIR}/libelf-${LIBELF_VERSION}
  cd ${BUILDDIR}/libelf-${LIBELF_VERSION}
  ../${SRCRELDIR}/libelf-${LIBELF_VERSION}/configure --host=${HOST_NATIVE} --prefix=$INSTALLDIR
  make ${JOBS} install

  echo "[Step 2.4] Build jansson..."
  do_download https://github.com/akheron/jansson/archive/v${JANSSON_VERSION}.tar.gz jansson-${JANSSON_VERSION}.tar.gz
  rm -rf ${BUILDDIR}/jansson-${JANSSON_VERSION}
  mkdir -p ${BUILDDIR}/jansson-${JANSSON_VERSION}
  cd ${BUILDDIR}/jansson-${JANSSON_VERSION}
  cmake -G"Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DCMAKE_BUILD_TYPE=Release -DJANSSON_BUILD_DOCS=OFF ${SRCDIR}/jansson-${JANSSON_VERSION}
  make ${JOBS} install

  if [[ "${HOST_NATIVE}" == *"mingw"* ]]; then
    echo "[Step 2.5] Build dlfcn-win32..."
    do_download https://github.com/dlfcn-win32/dlfcn-win32/archive/v${DLFCN_VERSION}.tar.gz dlfcn-${DLFCN_VERSION}.tar.gz
    cd ${SRCDIR}/dlfcn-win32-${DLFCN_VERSION}
    ./configure --prefix=${INSTALLDIR}
    make clean
    make ${JOBS}
    make install
  fi
fi

if [[ ${STEP_ALL} = true || ${STEP_TOOLCHAIN} = true ]]; then
  echo "[Step 3] Build vita-toolchain..."
  if [ ! -d ${SRCDIR}/vita-toolchain/.git ]; then
    rm -rf ${SRCDIR}/vita-toolchain
    git clone https://github.com/vitasdk/vita-toolchain -b master ${SRCDIR}/vita-toolchain
  else
    cd ${SRCDIR}/vita-toolchain
    git pull origin master
  fi
  rm -rf ${BUILDDIR}/vita-toolchain
  mkdir -p ${BUILDDIR}/vita-toolchain
  cd ${BUILDDIR}/vita-toolchain
  cmake -G"Unix Makefiles" -DCMAKE_C_FLAGS_RELEASE:STRING="-O3 -DNDEBUG -DZIP_STATIC" -DCMAKE_BUILD_TYPE=Release -DJansson_INCLUDE_DIR=$INSTALLDIR/include/ -DJansson_LIBRARY=$INSTALLDIR/lib/libjansson.a -Dlibelf_INCLUDE_DIR=$INSTALLDIR/include -Dlibelf_LIBRARY=$INSTALLDIR/lib/libelf.a -Dzlib_INCLUDE_DIR=$INSTALLDIR/include/ -Dzlib_LIBRARY=$INSTALLDIR/lib/libz.a -Dlibzip_INCLUDE_DIR=$INSTALLDIR/include/ -Dlibzip_CONFIG_INCLUDE_DIR=$INSTALLDIR/lib/libzip/include -Dlibzip_LIBRARY=$INSTALLDIR/lib/libzip.a -DCMAKE_INSTALL_PREFIX=${VITASDKROOT} -DDEFAULT_JSON=../share/db.json ${SRCDIR}/vita-toolchain
  make ${JOBS} install
fi

if [[ ${STEP_ALL} = true || ${STEP_BINUTILS} = true ]]; then
  echo "[Step 4] Build binutils..."
  do_download http://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.bz2
  if [ ${downloaded} = true ]; then
    cd ${SRCDIR}/binutils-${BINUTILS_VERSION}
    patch -p1 < ${PATCHDIR}/binutils.patch
    patch -p1 < ${PATCHDIR}/binutils-227.patch
    if [[ "${HOST_NATIVE}" == *"mingw"* ]]; then
      patch -p1 < ${PATCHDIR}/binutils-mingw.patch
    fi
  fi
  rm -rf ${BUILDDIR}/binutils-${BINUTILS_VERSION}
  mkdir -p ${BUILDDIR}/binutils-${BINUTILS_VERSION}
  cd ${BUILDDIR}/binutils-${BINUTILS_VERSION}
  ../${SRCRELDIR}/binutils-${BINUTILS_VERSION}/configure --host=${HOST_NATIVE} --build=${HOST_NATIVE} --target=${HOST_TARGET} --prefix=${VITASDKROOT} --infodir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/info --mandir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/man --htmldir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/html --pdfdir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/pdf --disable-nls --disable-werror --disable-sim --disable-gdb --enable-interwork --enable-plugins --with-sysroot=${VITASDKROOT}/${HOST_TARGET} --with-cloog=${INSTALLDIR} --with-isl=${INSTALLDIR} --disable-isl-version-check "--with-pkgversion=GNU Tools for ARM Embedded Processors [VitaSDK]"
  make ${JOBS}
  make install
fi

export VITASDK=${VITASDKROOT}
export OLDPATH=${PATH}
export PATH=${VITASDK}/bin:${PATH}
if [[ "${HOST_NATIVE}" == *"darwin"* ]]; then
  GCC_EXTRA_FLAGS='CXXFLAGS="-fbracket-depth=1024"'
fi

if [[ ${STEP_ALL} = true || ${STEP_GCC_FIRST} = true ]]; then
  echo "[Step 5] Build gcc first time..."
  do_download http://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2
  if [ ${downloaded} = true ]; then
    cd ${SRCDIR}/gcc-${GCC_VERSION}
    patch -p1 < ${PATCHDIR}/gcc.patch
    if [[ "${HOST_NATIVE}" == *"mingw"* ]]; then
      patch -p1 < ${PATCHDIR}/gcc-mingw.patch
    fi
  fi
  rm -rf ${BUILDDIR}/gcc-${GCC_VERSION}
  mkdir -p ${BUILDDIR}/gcc-${GCC_VERSION}
  cd ${BUILDDIR}/gcc-${GCC_VERSION}
  ../${SRCRELDIR}/gcc-${GCC_VERSION}/configure --host=${HOST_NATIVE} --build=${HOST_NATIVE} --target=${HOST_TARGET} --prefix=${VITASDKROOT} --libexecdir=${VITASDKROOT}/lib --infodir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/info --mandir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/man --htmldir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/html --pdfdir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/pdf --enable-languages=c,c++ --disable-decimal-float --disable-libffi --disable-libgomp --disable-libmudflap --disable-libquadmath --disable-libssp --disable-libstdcxx-pch --disable-nls --disable-shared --disable-threads --disable-tls --with-newlib --without-headers --with-gnu-as --with-gnu-ld --with-python-dir=share/gcc-${HOST_TARGET} --with-sysroot=${VITASDKROOT}/${HOST_TARGET} --with-libiconv-prefix=${INSTALLDIR} --with-gmp=${INSTALLDIR} --with-mpfr=${INSTALLDIR} --with-mpc=${INSTALLDIR} --with-isl=${INSTALLDIR} --with-libelf=${INSTALLDIR} "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"  "--with-pkgversion=GNU Tools for ARM Embedded Processors [VitaSDK]" --disable-multilib --with-arch=armv7-a --with-tune=cortex-a9 --with-fpu=neon --with-float=hard --with-mode=thumb
  make ${JOBS} all-gcc ${GCC_EXTRA_FLAGS}
  make install-gcc
fi

if [[ ${STEP_ALL} = true || ${STEP_HEADERS} = true ]]; then
  echo "[Step 6] Build vita-headers..."
  if [ ! -d ${SRCDIR}/vita-headers/.git ]; then
    rm -rf ${SRCDIR}/vita-headers
    git clone https://github.com/vitasdk/vita-headers -b master ${SRCDIR}/vita-headers
  else
    cd ${SRCDIR}/vita-headers
    git pull origin master
  fi
  rm -rf ${BUILDDIR}/vita-headers
  mkdir -p ${BUILDDIR}/vita-headers
  cd ${BUILDDIR}/vita-headers
  vita-libs-gen ${SRCDIR}/vita-headers/db.json .
  make ARCH=${VITASDKROOT}/bin/${HOST_TARGET} ${JOBS}
  cp *.a ${VITASDKROOT}/${HOST_TARGET}/lib/
  cp -r ${SRCDIR}/vita-headers/include ${VITASDKROOT}/${HOST_TARGET}/
  mkdir -p ${VITASDKROOT}/share
  cp ${SRCDIR}/vita-headers/db.json ${VITASDKROOT}/share
fi

if [[ ${STEP_ALL} = true || ${STEP_NEWLIB} = true ]]; then
  echo "[Step 7] Build newlib..."
  if [ ! -d ${SRCDIR}/newlib/.git ]; then
    rm -rf ${SRCDIR}/newlib
    git clone https://github.com/vitasdk/newlib -b vita ${SRCDIR}/newlib
  else
    cd ${SRCDIR}/newlib
    git pull origin vita
  fi
  rm -rf ${BUILDDIR}/newlib
  mkdir -p ${BUILDDIR}/newlib
  cd ${BUILDDIR}/newlib
  ../${SRCRELDIR}/newlib/configure --host=${HOST_NATIVE} --build=${HOST_NATIVE} --target=${HOST_TARGET} --prefix=${VITASDKROOT} --infodir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/info --mandir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/man --htmldir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/html --pdfdir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/pdf --enable-newlib-io-long-long --enable-newlib-register-fini --disable-newlib-supplied-syscalls --disable-nls
  make ${JOBS}
  make install
fi

if [[ ${STEP_ALL} = true || ${STEP_PTHREAD} = true ]]; then
  echo "[Step 8] Build pthread..."
  if [ ! -d ${SRCDIR}/pthread-embedded/.git ]; then
    rm -rf ${SRCDIR}/pthread-embedded
    git clone https://github.com/vitasdk/pthread-embedded -b master ${SRCDIR}/pthread-embedded
  else
    cd ${SRCDIR}/pthread-embedded
    git pull origin master
  fi
  rm -rf ${BUILDDIR}/pthread-embedded
  mkdir -p ${BUILDDIR}/pthread-embedded
  cd ${BUILDDIR}/pthread-embedded
  cp -R ../${SRCRELDIR}/pthread-embedded/* .
  cd platform/vita
  make ${JOBS} CFLAGS_FOR_TARGET='-g -O2 -ffunction-sections -fdata-sections'
  make install
fi

if [[ ${STEP_ALL} = true || ${STEP_GCC_FINAL} = true ]]; then
  echo "[Step 9] Build gcc final..."
  if [ ! -d ${SRCDIR}/gcc-${GCC_VERSION} ]; then
    do_download http://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.bz2
    if [ ${downloaded} = true ]; then
      cd ${SRCDIR}/gcc-${GCC_VERSION}
      patch -p1 < ${PATCHDIR}/gcc.patch
      if [[ "${HOST_NATIVE}" == *"mingw"* ]]; then
        patch -p1 < ${PATCHDIR}/gcc-mingw.patch
      fi
    fi
  fi
  pushd ${VITASDKROOT}/${HOST_TARGET}
  mkdir -p ./usr
  cp -rf include lib usr/
  popd
  rm -rf ${BUILDDIR}/gcc-${GCC_VERSION}-final
  mkdir -p ${BUILDDIR}/gcc-${GCC_VERSION}-final
  cd ${BUILDDIR}/gcc-${GCC_VERSION}-final
  ../${SRCRELDIR}/gcc-${GCC_VERSION}/configure --host=${HOST_NATIVE} --build=${HOST_NATIVE} --target=${HOST_TARGET} --prefix=${VITASDKROOT} --libexecdir=${VITASDKROOT}/lib --infodir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/info --mandir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/man --htmldir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/html --pdfdir=${VITASDKROOT}/share/doc/gcc-${HOST_TARGET}/pdf --enable-languages=c,c++ --enable-plugins --enable-threads=posix --disable-decimal-float --disable-libffi --disable-libgomp --disable-libmudflap --disable-libquadmath --disable-libssp --disable-libstdcxx-pch --disable-libstdcxx-verbose --disable-nls --disable-shared --disable-tls --with-gnu-as --with-gnu-ld --with-newlib --with-headers=yes --with-python-dir=share/gcc-${HOST_TARGET} --with-sysroot=${VITASDKROOT}/${HOST_TARGET} --with-libiconv-prefix=${INSTALLDIR} --with-gmp=${INSTALLDIR} --with-mpfr=${INSTALLDIR} --with-mpc=${INSTALLDIR} --with-isl=${INSTALLDIR} --with-libelf=${INSTALLDIR}  "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm" "--with-pkgversion=GNU Tools for ARM Embedded Processors [VitaSDK]" --disable-multilib --with-arch=armv7-a --with-tune=cortex-a9 --with-fpu=neon --with-float=hard --with-mode=thumb
  make ${JOBS} INHIBIT_LIBC_CFLAGS="-DUSE_TM_CLONE_REGISTRY=0" ${GCC_EXTRA_FLAGS}
  make install

  pushd ${VITASDKROOT}
  rm -rf bin/${HOST_TARGET}-gccbug
  LIBIBERTY_LIBRARIES=`find ${VITASDKROOT}/${HOST_TARGET}/lib -name libiberty.a`
  for libiberty_lib in $LIBIBERTY_LIBRARIES ; do
      rm -rf $libiberty_lib
  done
  rm -rf ./lib/libiberty.a
  rmdir include
  rm -rf ./${HOST_TARGET}/usr
  popd
fi

if [[ ${STEP_ALL} = true || ${STEP_STRIP} = true ]]; then
  echo "[Step 10] Strip binaries..."

  find ${VITASDKROOT} -name '*.la' -type f -exec rm '{}' ';'
  find ${VITASDKROOT} -executable -type f -exec strip '{}' ';'

  for target_lib in `find ${VITASDKROOT}/${HOST_TARGET}/lib -name \*.a` ; do
      ${HOST_TARGET}-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_lib || true
  done

  for target_obj in `find ${VITASDKROOT}/${HOST_TARGET}/lib -name \*.o` ; do
      ${HOST_TARGET}-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_obj || true
  done

  for target_lib in `find ${VITASDKROOT}/lib/gcc/${HOST_TARGET}/${GCC_VERSION} -name \*.a` ; do
      ${HOST_TARGET}-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_lib || true
  done

  for target_obj in `find ${VITASDKROOT}/lib/gcc/${HOST_TARGET}/${GCC_VERSION} -name \*.o` ; do
      ${HOST_TARGET}-objcopy -R .comment -R .note -R .debug_info -R .debug_aranges -R .debug_pubnames -R .debug_pubtypes -R .debug_abbrev -R .debug_line -R .debug_str -R .debug_ranges -R .debug_loc $target_obj || true
 done
fi

export PATH=${OLDPATH}
export -n OLDPATH
echo "[DONE] Everything is OK!"

