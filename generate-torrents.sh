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
		_web_args=("${_web_args[@]}" "-w" "${URL}${_file}")
	done

	_tracker_args=()
	for TRACKER in "${TRACKERS[@]}"; do
		_tracker_args=("${_tracker_args[@]}" "-a" "${TRACKER}")
	done

	TEMPFILE="$(mktemp --tmpdir torrent-XXXXXX.torrent)"
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

get_hash_for_torrent() {
	local _file="$1"; shift
	transmission-show "${_file}" | grep Hash: | awk '{ print $NF }'
}

get_name_for_torrent() {
	local _file="$1"; shift
	transmission-show "${_file}" | grep -E '^Name:' | awk '{ print $NF }'
}

get_magnet_uri_for_torrent() {
	local _file="$1"; shift
	transmission-show --magnet "${_file}"
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

RSSTMP="$(mktemp --tmpdir torrent.rss.XXXXXX)"
MAGNETTMP="$(mktemp --tmpdir magnet.rss.XXXXXX)"

echo "* generating RSS feed..."

cd "${TORRENT_DIR}" || exit 1

PUBDATE="$(date +"%a, %d %b %Y %H:00:00 GMT")"
BUILDDATE="$(date +"%a, %d %b %Y %H:%M:%S GMT")"

cat <<END >>"${RSSTMP}"
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
	<channel>
		<title>ravynOS development snapshots</title>
		<link>https://ravynos-seed.raccoonfink.com/feed.rss</link>
		<description>Development Snapshot Builds of ravynOS, generated (usually) nightly</description>
		<language>en-CA</language>
		<pubDate>${PUBDATE}</pubDate>
		<lastBuildDate>${BUILDDATE}</lastBuildDate>
		<generator>https://github.com/RangerRick/ravynos-nightly-torrent-seed</generator>
		<docs>https://validator.w3.org/feed/docs/rss2.html</docs>
		<ttl>60</ttl>
END

cat "${RSSTMP}" >> "${MAGNETTMP}"

echo '		<atom:link href="https://ravynos-seed.raccoonfink.com/feed.rss" rel="self" type="application/rss+xml" />' >> "${RSSTMP}"
echo '		<atom:link href="https://ravynos-seed.raccoonfink.com/magnet.rss" rel="self" type="application/rss+xml" />' >> "${MAGNETTMP}"

# example item:
#        <item>
#            <title>0 A.D. Alpha 25b - macOS (amd64)</title>
#            <description>Torrent for 0ad - macOS (amd64)</description>
#            <link>https://fosstorrents.com/files/0ad-0.0.25b-alpha-osx64.dmg.torrent</link>
#            <guid isPermaLink="false">968147694127a441925290fd6a0f0048e553aea32a4847c37cb493de7f8a0084</guid>
#            <pubDate>Wed, 29 Sep 2021 21:18:45 ADT</pubDate>
#        </item>

for TORRENT in $(ls -1rt *.torrent); do
	torrent_name="$(get_name_for_torrent "${TORRENT}")"
	torrent_hash="$(get_hash_for_torrent "${TORRENT}")"
	magnet_uri="$(get_magnet_uri_for_torrent "${TORRENT}")"

	torrent_date="$(date -r "${TORRENT}" +"%a, %d %b %Y %H:00:00 GMT")"
	cat <<END >>"${RSSTMP}"
		<item>
			<title>${torrent_name}</title>
			<link>https://ravynos-seed.raccoonfink.com/${TORRENT}</link>
			<guid isPermaLink="false">torrent.${torrent_hash}</guid>
			<pubDate>${torrent_date}</pubDate>
		</item>
END
	cat <<END >>"${MAGNETTMP}"
		<item>
			<title>${torrent_name}</title>
			<link>${magnet_uri}</link>
			<guid isPermaLink="false">magnet.${torrent_hash}</guid>
			<pubDate>${torrent_date}</pubDate>
		</item>
END
done

cat <<END >>"${RSSTMP}"
	</channel>
</rss>
END
cat <<END >>"${MAGNETTMP}"
	</channel>
</rss>
END

chmod 644 "${RSSTMP}"
chmod 644 "${MAGNETTMP}"
mv "${RSSTMP}" "${TORRENT_DIR}/feed.rss"
mv "${MAGNETTMP}" "${TORRENT_DIR}/magnet.rss"
cd - >/dev/null || exit 1

echo "done"
