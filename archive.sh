#!/usr/bin/env bash

BASE_PATH=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo .)")"; pwd)
ARCHIVE_PATH=${BASE_PATH}/build/
TFA_BUILD_PATH=${BASE_PATH}/trusted-firmware-a/build/a3700/release/flash-image.bin

# build
make clean
if ! (make CLOCKSPRESET=CPU_1000_DDR_800); then exit $?; fi

# archive
mkdir -p ${ARCHIVE_PATH}
cp ${TFA_BUILD_PATH} "$ARCHIVE_PATH/$(date +"%Y%m%d-%H%M").bin"
cp ${TFA_BUILD_PATH} "$ARCHIVE_PATH/latest.bin"

# build
make clean
if ! (make CLOCKSPRESET=CPU_1200_DDR_750); then exit $?; fi

# archive
cp ${TFA_BUILD_PATH} "$ARCHIVE_PATH/test.bin"

# log
echo "$(date --iso-8601=minutes)  $(git log -n 1 --pretty=oneline --abbrev-commit)" >> ${ARCHIVE_PATH}/log.txt
sync