#!/bin/bash

ROOT_DIR="$(pwd)"
BINUTILS_VERSION="2.43"
GCC_VERSION="14.2.0"
NUM_JOBS="4"

WINDOWS_HOST="i686-w64-mingw32"

if [ $# -eq 2 ]; then
	PACKAGE_NAME="$1"
	TARGET_NAME="$2"
	BUILD_OPTIONS=""
elif [ $# -eq 3 ]; then
	PACKAGE_NAME="$1"
	TARGET_NAME="$2"
	BUILD_OPTIONS="--build=x86_64-linux-gnu --host=$3"
else
	echo "Usage: $0 <package name> <target triplet> [host triplet]"
	exit 0
fi

## Detect Windows cross build

CROSS_WINDOWS=0

if [[ "$BUILD_OPTIONS" == *"$WINDOWS_HOST"* ]]; then
	CROSS_WINDOWS=1
fi

## Download binutils and GCC

if [ ! -d binutils-$BINUTILS_VERSION ]; then
	wget "https://ftpmirror.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz" \
		|| exit 1

	tar Jxf binutils-$BINUTILS_VERSION.tar.xz \
		|| exit 1

	rm -f binutils-$BINUTILS_VERSION.tar.xz
fi

if [ ! -d gcc-$GCC_VERSION ]; then
	wget "https://ftpmirror.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" \
		|| exit 1

	tar Jxf gcc-$GCC_VERSION.tar.xz \
		|| exit 1

	cd gcc-$GCC_VERSION

	contrib/download_prerequisites \
		|| exit 1

	cd ..

	rm -f gcc-$GCC_VERSION.tar.xz
fi

##################################################
## Build binutils
##################################################

mkdir -p binutils-build
cd binutils-build

../binutils-$BINUTILS_VERSION/configure \
	--prefix="$ROOT_DIR/$PACKAGE_NAME" \
	$BUILD_OPTIONS \
	--target=$TARGET_NAME \
	--with-float=soft \
	--disable-docs \
	--disable-nls \
	--disable-werror \
	--disable-gdb \
	--disable-sim \
	|| exit 2

make -j $NUM_JOBS \
	|| exit 2

make install-strip \
	|| exit 2

cd ..
rm -rf binutils-build

##################################################
## Build GCC
##################################################

mkdir -p gcc-build
cd gcc-build

GCC_EXTRA_OPTIONS=""

if [ $CROSS_WINDOWS -eq 1 ]; then
	GCC_EXTRA_OPTIONS="\
		--disable-bootstrap \
		--enable-static \
		--disable-shared \
	"
fi

../gcc-$GCC_VERSION/configure \
	--prefix="$ROOT_DIR/$PACKAGE_NAME" \
	$BUILD_OPTIONS \
	--target=$TARGET_NAME \
	--with-float=soft \
	--disable-docs \
	--disable-nls \
	--disable-werror \
	--disable-libada \
	--disable-libssp \
	--disable-libquadmath \
	--disable-threads \
	--disable-libgomp \
	--disable-libstdcxx-pch \
	--disable-hosted-libstdcxx \
	--enable-languages=c,c++ \
	--without-isl \
	--without-headers \
	--with-gnu-as \
	--with-gnu-ld \
	--disable-multilib \
	$GCC_EXTRA_OPTIONS \
	|| exit 3

make all-gcc -j $NUM_JOBS \
	|| exit 3

make install-gcc \
	|| exit 3

cd ..
rm -rf gcc-build

##################################################
## Package toolchain
##################################################

#if [ $CROSS_WINDOWS -eq 1 ]; then
	#cd $PACKAGE_NAME

	#zip -9 -r ../$PACKAGE_NAME-windows.zip . \
		|| exit 4

	$cd ..
#fi