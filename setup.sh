#!/bin/bash

# Copyright 2021 Da Xue

if [ "$USER" = "root" ]; then
	echo "This script should not run as root!"
	exit 1
fi

if [ $# -ne 4 ]; then
	echo "$0 CONTAINER BOARD BRANCH TARGET"
	exit 1
fi

CONTAINER=$1
BOARD=$2
BRANCH=$3
TARGET=$4

SDK_DIR=/opt/release_p_9.0_20190415_aosp
SDK_FILE=release_p_9.0_20190415_aosp.tar.bz2
if [ ! -f "$SDK_FILE" ]; then
	echo "$SDK_FILE does not exist!"
	exit 1
fi

DEVICEID_FILE=deviceid.apk
if [ ! -f "$DEVICEID_FILE" ]; then
	echo "$DEVICEID_FILE does not exist!"
	exit 1
fi

CONTAINERS=$(lxc list -f csv | cut -f 1 -d ,)
container_found=0
for container in $CONTAINERS; do
	if [ "$CONTAINER" = "$container" ]; then
		if [ "$CONTAINER_EXISTING" -eq 1 ]; then
			container_found=1
			break
		else
			echo "$CONTAINER already exists!"
			exit 1
		fi
	fi
done

if [ "$CONTAINER_EXISTING" -eq 1 ]; then
	if [ "$container_found" -eq 0 ]; then
		echo "$CONTAINER does not exist!"
		exit 1
	fi
fi

BOARDS=(aml-s805x-ac aml-s905x-cc)

board_found=0
for board in ${BOARDS[@]}; do
	if [ "$BOARD" = "$board" ]; then
		board_found=1
		break
	fi
done

if [ "$board_found" -eq 0 ]; then
	echo "$BOARD is not supported!"
	exit 1
fi

declare -A BOARD_AMLOGIC_NAMES
BOARD_AMLOGIC_NAMES[aml-s805x-ac]="curie"
BOARD_AMLOGIC_NAMES[aml-s905x-cc]="ampere"

declare -A BOARD_DT_NAMES
BOARD_DT_NAMES[aml-s805x-ac]="gxl_p241_v1"
BOARD_DT_NAMES[aml-s905x-cc]="gxl_p212_v1"

declare -A BRANCHES
BRANCHES[aml-s805x-ac]="android-p-amlogic-20190415-aosp"
BRANCHES[aml-s905x-cc]="android-p-amlogic-20190415-aosp android-p-amlogic-20190415-aosp-sd"

branch_found=0
for branch in ${BRANCHES[$BOARD]}; do
	if [ "$BRANCH" = "$branch" ]; then
		branch_found=1
		break
	fi
done

if [ "$branch_found" -eq 0 ]; then
	echo "$BRANCH is not supported!"
	exit 1
fi

declare -A TARGETS
TARGETS[aml-s805x-ac]="user userdebug eng"
TARGETS[aml-s905x-cc]="user userdebug eng"

target_found=0
for target in ${TARGETS[$BOARD]}; do
	if [ "$TARGET" = "$target" ]; then
		target_found=1
		break
	fi
done

if [ "$CONTAINER_EXISTING" -eq 1 ]; then
	echo "Re-using existing container."
else
	lxc launch ubuntu:18.04 $CONTAINER
	lxc file push $SDK_FILE $CONTAINER/
fi
lxc file push $DEVICEID_FILE $CONTAINER/

lxc file push build.sh $CONTAINER/

CONFIG_FILE=$(mktemp)

echo "BOARD=$BOARD" >> $CONFIG_FILE
echo "BOARD_AMLOGIC_NAME=${BOARD_AMLOGIC_NAMES[$BOARD]}" >> $CONFIG_FILE
echo "BOARD_DT_NAME=${BOARD_DT_NAMES[$BOARD]}" >> $CONFIG_FILE
echo "BRANCH=$BRANCH" >> $CONFIG_FILE
echo "TARGET=$TARGET" >> $CONFIG_FILE
echo "SDK_DIR=$SDK_DIR" >> $CONFIG_FILE
echo "SDK_FILE=$SDK_FILE" >> $CONFIG_FILE
echo "DEVICEID_FILE=$DEVICEID_FILE" >> $CONFIG_FILE

lxc file push $CONFIG_FILE $CONTAINER/build_config.sh

lxc exec $CONTAINER /build.sh

lxc file pull $CONTAINER$SDK_DIR/out/target/product/${BOARD_AMLOGIC_NAMES[$BOARD]}/aml_upgrade_package.img $BOARD.img
