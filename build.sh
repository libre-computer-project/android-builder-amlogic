#!/bin/bash

if [ "$USER" != "root" ]; then
	echo "This script must run as root!"
	exit 1
fi

set -e

cd /

if [ ! -f "build_config.sh" ]; then
	echo "Build configuration missing!"
	exit 1
fi

. build_config.sh

if [ ! -f "$SDK_FILE" ]; then
	echo "SDK file missing!"
	exit 1
fi

apt-get update
apt-get dist-upgrade -y
apt-get install -y lbzip2 ninja-build python bison build-essential zip gcc-multilib u-boot-tools m4 git-lfs gcc-arm-none-eabi lib32z1

if [ ! -d "$SDK_DIR" ]; then
	tar -I lbzip2 -xf $SDK_FILE -C /opt
fi

if [ ! -d "/opt/gcc-linaro-aarch64-none-elf-4.8-2013.11_linux" ]; then
	wget -O - https://releases.linaro.org/archive/13.11/components/toolchain/binaries/gcc-linaro-aarch64-none-elf-4.8-2013.11_linux.tar.xz | tar -xJC /opt
fi

cd $SDK_DIR

#PULL GITHUB CHANGES TO SDK

cd bootloader/uboot-repo/bl33
if ! git remote show lc-github; then
git remote add lc-github https://github.com/libre-computer-project/amlogic-bootloader-uboot-repo-bl33.git
git fetch lc-github $BRANCH
git rebase FETCH_HEAD
fi
cd ../../..

cd common
if ! git remote show lc-github; then
git remote add lc-github https://github.com/libre-computer-project/amlogic-common.git
git fetch lc-github $BRANCH
git rebase FETCH_HEAD
fi
cd ..

cd device/amlogic
if ! git remote show lc-github; then
git remote add lc-github https://github.com/libre-computer-project/amlogic-device-amlogic.git
git fetch lc-github $BRANCH
git rebase FETCH_HEAD
fi
cd ../..

cd vendor/amlogic/common/apps/DroidTvSettings
if ! git remote show lc-github; then
git remote add lc-github https://github.com/libre-computer-project/amlogic-vendor-amlogic-common-apps-DroidTvSettings.git
git fetch lc-github $BRANCH
git rebase FETCH_HEAD
fi
cd ../../../../..

#DEVICE ID APK

if [ ! -d "$SDK_DIR/packages/apps/DeviceID" ]; then
mkdir -p $SDK_DIR/packages/apps/DeviceID
cp /$DEVICEID_FILE $SDK_DIR/packages/apps/DeviceID/deviceid.apk
tee $SDK_DIR/packages/apps/DeviceID/Android.mk <<EOF
LOCAL_PATH := \$(call my-dir)
include \$(CLEAR_VARS)
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE := DeviceID
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := deviceid.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := \$(COMMON_ANDROID_PACKAGE_SUFFIX)
include \$(BUILD_PREBUILT)
EOF
fi

#OPENGAPPS

mkdir -p vendor/opengapps/sources
if [ ! -d vendor/opengapps/build/.git ]; then
git clone https://github.com/opengapps/aosp_build vendor/opengapps/build
cd vendor/opengapps/build
git lfs pull
cd ../../..
fi
if [ ! -d vendor/opengapps/sources/all/.git ]; then
git clone https://gitlab.opengapps.org/opengapps/all --depth=1 --single-branch vendor/opengapps/sources/all
cd vendor/opengapps/sources/all
git lfs pull
cd ../../../..
fi
if [ ! -d vendor/opengapps/sources/arm/.git ]; then
git clone https://gitlab.opengapps.org/opengapps/arm --depth=1 --single-branch vendor/opengapps/sources/arm
cd vendor/opengapps/sources/arm
git lfs pull
cd ../../../..
fi

#U-BOOT
if [ ! -d "/opt/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf" ]; then
	wget -O - https://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf.tar.xz | tar -xJC /opt
fi
if [ ! -d "/opt/gcc-arm-none-eabi-6-2017-q2-update" ]; then
	wget -O - https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/6-2017q2/gcc-arm-none-eabi-6-2017-q2-update-linux.tar.bz2 | tar -xjC /opt
fi

cd bootloader/uboot-repo

./mk $BOARD_DT_NAME --systemroot

cp build/* ../../device/amlogic/$BOARD_AMLOGIC_NAME/upgrade/
cp build/u-boot.bin ../../device/amlogic/$BOARD_AMLOGIC_NAME/bootloader.img

cd ../..

#BUILD ANDROID

. build/envsetup.sh

lunch $BOARD_AMLOGIC_NAME-$TARGET

make otapackage
