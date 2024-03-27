#!/bin/bash
set -e

ID=${1}
PACKAGE_NAME="thinlinc"
PROJECT_URL="https://www.cendio.com/downloads/clients"
ARCHIVE_URL="${PROJECT_URL}/tl-${ID}-client-linux-dynamic-CPU.tar.gz"

if [[ -z "${ID}" ]]; then
  echo "tag name or commit sha required (see ${URL})"
  exit 1
fi

# function to download archive hash for certain CPU
function updateHash() {
  local cpu=${1}
  # download archive for hash update
  ARCHIVE_HASH=$(wget --passive-ftp -nd -t 3 -O - "${ARCHIVE_URL/CPU/${cpu}}" | sha256sum | awk '{ print $1 }')
  if [[ -n "${ARCHIVE_HASH}" ]]; then
    sed -i "/-${cpu}\.tar.gz/d" "buildroot-external/package/${PACKAGE_NAME}/${PACKAGE_NAME}.hash"
    echo "sha256  ${ARCHIVE_HASH}  tl-${ID}-client-linux-dynamic-${cpu}.tar.gz" >>"buildroot-external/package/${PACKAGE_NAME}/${PACKAGE_NAME}.hash"
  fi
}

# update package info
BR_PACKAGE_NAME=${PACKAGE_NAME^^}
BR_PACKAGE_NAME=${BR_PACKAGE_NAME//-/_}
sed -i "s/${BR_PACKAGE_NAME}_VERSION = .*/${BR_PACKAGE_NAME}_VERSION = ${ID}/g" "buildroot-external/package/${PACKAGE_NAME}/${PACKAGE_NAME}.mk"

# update package hashes
updateHash x86_64
updateHash armhf
