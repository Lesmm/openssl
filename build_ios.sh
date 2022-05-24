#!/bin/bash

# Tested on branch: OpenSSL_1_1_1b

# set -x

PWD=$(pwd)
BUILD_DIR=${PWD}/build

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

CROSS_TOP_SIM="`xcode-select --print-path`/Platforms/iPhoneSimulator.platform/Developer"
CROSS_SDK_SIM="iPhoneSimulator.sdk"
CROSS_TOP_IOS="`xcode-select --print-path`/Platforms/iPhoneOS.platform/Developer"
CROSS_SDK_IOS="iPhoneOS.sdk"

export CROSS_COMPILE=`xcode-select --print-path`/Toolchains/XcodeDefault.xctoolchain/usr/bin/

function build_for () {
  PLATFORM=$1
  ARCH=$2
  ENV=$3

  echo "\n"
  echo "------------------ Building ------------------ "
  echo "PLATFORM: $PLATFORM, ARCH: $ARCH, ENV: $ENV"
  echo "\n"

  CROSS_TOP_ENV=CROSS_TOP_${ENV}
  CROSS_SDK_ENV=CROSS_SDK_${ENV}

  make clean

  export CROSS_TOP="${!CROSS_TOP_ENV}"
  export CROSS_SDK="${!CROSS_SDK_ENV}"

  ./Configure $PLATFORM "-arch $ARCH -fembed-bitcode" no-asm no-shared no-hw no-async --prefix=${BUILD_DIR}/${ARCH} || exit 1

  make && make install_sw || exit 2

  unset CROSS_TOP
  unset CROSS_SDK
}

function package_for () {
  LIB_NAME=$1

  mkdir -p ${BUILD_DIR}/lib/

  lipo \
	${BUILD_DIR}/x86_64/lib/lib${LIB_NAME}.a \
	${BUILD_DIR}/armv7s/lib/lib${LIB_NAME}.a \
	${BUILD_DIR}/arm64/lib/lib${LIB_NAME}.a \
	-output ${BUILD_DIR}/lib/lib${LIB_NAME}.a -create
}

# build
build_for ios64sim-cross x86_64 SIM || exit 3
build_for ios-cross armv7s IOS || exit 4
build_for ios64-cross arm64 IOS || exit 5

# package
package_for ssl || exit 6
package_for crypto || exit 7

# copy the include header files
cp -r ${BUILD_DIR}/armv7s/include ${BUILD_DIR}/
patch -p3 ${BUILD_DIR}/include/openssl/opensslconf.h < build_ios_patch_include.patch


RELEASE_DIR=${BUILD_DIR}/release

# copy the static libraries
BUILD_DIR_DIST=${RELEASE_DIR}/__static_libraries__
rm -rf ${BUILD_DIR_DIST}
mkdir -p ${BUILD_DIR_DIST}
cp -r ${BUILD_DIR}/include ${BUILD_DIR_DIST}/
cp -r ${BUILD_DIR}/lib ${BUILD_DIR_DIST}/

# generate the framework files
BUILD_DIR_RELEASE=${RELEASE_DIR}/__frameworks__
rm -rf ${BUILD_DIR_RELEASE}
mkdir -p ${BUILD_DIR_RELEASE}
cp -r ${BUILD_DIR}/include ${BUILD_DIR_RELEASE}/
lipo -create ${BUILD_DIR}/armv7s/lib/libssl.a ${BUILD_DIR}/arm64/lib/libssl.a ${BUILD_DIR}/x86_64/lib/libssl.a -o ${BUILD_DIR_RELEASE}/libssl.framework
lipo -create ${BUILD_DIR}/armv7s/lib/libcrypto.a ${BUILD_DIR}/arm64/lib/libcrypto.a ${BUILD_DIR}/x86_64/lib/libcrypto.a -o ${BUILD_DIR_RELEASE}/libcrypto.framework

