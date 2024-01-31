#!/usr/bin/env bash

BASE_PATH=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo .)")"; pwd)
ARCHIVE_PATH=${BASE_PATH}/build/
TFA_BUILD_PATH=${BASE_PATH}/trusted-firmware-a/build/a3700/release/flash-image.bin
BUILD_TIME=$(date +"%Y%m%d-%H%M")

# build
make clean
if ! (make); then exit $?; fi

# archive
mkdir -p ${ARCHIVE_PATH}
cp ${TFA_BUILD_PATH} "$ARCHIVE_PATH/$BUILD_TIME.bin"
cp ${TFA_BUILD_PATH} "$ARCHIVE_PATH/latest.bin"

# log
echo "$BUILD_TIME  $(git log -n 1 --pretty=oneline --abbrev-commit)" >> ${ARCHIVE_PATH}/log.txt
sync