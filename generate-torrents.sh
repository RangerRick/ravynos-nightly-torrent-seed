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

if [ -z "${TRACKERS}" ]; then
	echo "\$TRACKERS must be defined in ${TOPDIR}/env"
	exit 1
fi

if [ -z "${WEB_MIRRORS}" ]; then
	echo "\$WEB_MIRRORS must be defined in ${TOPDIR}/env"
	exit 1
fi

mkdir -p "${TORRENT_DIR}"

generate_torrent() {
	local _file="$1"; shift

	local _isofile="${LOCAL_DIR}/${_file}"
	local _torrentfile="${TORRENT_DIR}/${_file}.torrent"

	local _mkt_piece=18
	local _pieces=9999
	local _k512=524288

	cd "${LOCAL_DIR}" || exit 1

	local _size="$(ls -l "${_file}" | awk '{ print $5 }')"

	#echo "  * size of ${_isofile}: ${_size} bytes"

	# calculate optimal piece length
	while [ "${_pieces}" -gt 2200 ]; do
		_pieces="$((_size / _k512))"
		_mkt_piece="$((_mkt_piece + 1))"
		_k512="$(($_k512 + $_k512))"
	done

	#echo "  * torrent pieces: ${_pieces}"
	#echo "  * torrent piece length: ${_mkt_piece}"

	_web_args=()
	for URL in "${WEB_MIRRORS[@]}"; do
		_web_args=("${_web_args[@]}" "-w" "${URL}/${_file}")
	done

	_tracker_args=()
	for TRACKER in "${TRACKERS[@]}"; do
		_tracker_args=("${_tracker_args[@]}" "-a" "${TRACKER}")
	done

	TEMPFILE="$(mktemp /tmp/torrent-XXXXXX.torrent)"
	rm -f "${TEMPFILE}"
	mktorrent \
		"${_tracker_args[@]}" \
		"${_web_args[@]}" \
		-l "${_mkt_piece}" \
		-o "${TEMPFILE}" \
		"${_isofile}" 2>&1 | grep -v Hashed | grep -v -E '^$'
	mv "${TEMPFILE}" "${_torrentfile}"
	touch -r "${_isofile}" "${_torrentfile}"
	cd - >/dev/null || exit 1
}

echo "* generating torrents..."
cd "${LOCAL_DIR}" || exit 1
find * -type f -name \*.iso | while read -r ISO; do
	if [ -e "${TORRENT_DIR}/${ISO}.torrent" ]; then
		echo "* ${ISO}.torrent: exists"
	else
		echo "* ${ISO}.torrent: generating"
		generate_torrent "${ISO}"
	fi
done

echo "* removing outdated torrent files that don't have ISO files anymore..."
cd "${TORRENT_DIR}" || exit 1
for TORRENT in *.torrent; do
	ISOFILE="${TORRENT//.torrent/}"
	if [ ! -e "${LOCAL_DIR}/${ISOFILE}" ]; then
		rm -f "${TORRENT}"
		echo "* removed ${TORRENT}"
	fi
done
cd - >/dev/null || exit 1

echo "done"
