#!/bin/bash

set -e
set -o pipefail

TOPDIR="$(cd "$(dirname "$0")"; pwd)"

"${TOPDIR}/sync-nightly.sh"
"${TOPDIR}/generate-torrents.sh"
"${TOPDIR}/seed-torrents.sh"
