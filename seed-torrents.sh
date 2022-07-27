#!/bin/bash

set -e
set -o pipefail

TOPDIR="$(cd "$(dirname "$0")"; pwd)"
. "${TOPDIR}/env"

if [ -z "${LOCAL_DIR}" ]; then
	echo "\$LOCAL_DIR must be defined in ${TOPDIR}/env"
	exit 1
fi

if [ ! -d "${LOCAL_DIR}" ]; then
	echo "local mirror directory ${LOCAL_DIR} does not exist"
	exit 1
fi

if [ -z "${TORRENT_DIR}" ]; then
	echo "\$TORRENT_DIR must be defined in ${TOPDIR}/env"
	exit 1
fi

if [ ! -d "${TORRENT_DIR}" ]; then
	echo "local torrent directory ${TORRENT_DIR} does not exist"
	exit 1
fi

cd "${TORRENT_DIR}" || exit 1

echo "* adding torrents to Transmission..."

ls -1 *.torrent | sort | while read -r TORRENT; do
	transmission-remote -a "${TORRENT}" -w "${LOCAL_DIR}" >/dev/null 2>&1 && echo "  * ${TORRENT}"
done
echo "done"

echo "* removing stale torrents from Transmission..."
transmission-remote -l | grep -v ETA | grep -v Sum: | while read LINE; do
	ID="$(echo "$LINE" | awk '{ print $1 }')"
	ISO="$(echo "$LINE" | awk '{ print $NF }')"
	if [ ! -e "${LOCAL_DIR}/${ISO}" ]; then
		if transmission-remote -t "$ID" -r >/dev/null 2>&1; then
			echo "  * $ISO was removed"
		else
			echo "  * failed to remove $ISO from transmission"
		fi
	fi
done
echo "done"
