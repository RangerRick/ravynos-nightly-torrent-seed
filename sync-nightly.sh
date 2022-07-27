#!/bin/bash

set -e
set -o pipefail

TOPDIR="$(cd "$(dirname "$0")"; pwd)"
. "${TOPDIR}/env"

if [ -z "${RSYNC_SOURCE}" ]; then
	echo "\$RSYNC_SOURCE must be defined in ${TOPDIR}/env"
	exit 1
fi

if [ -z "${LOCAL_DIR}" ]; then
	echo "\$LOCAL_DIR must be defined in ${TOPDIR}/env"
	exit 1
fi

mkdir -p "${LOCAL_DIR}"

echo "* syncing from upstream..."
rsync -avr --progress --delete --exclude='*.torrent' "${RSYNC_SOURCE}/" "${LOCAL_DIR}/"

echo "done"
