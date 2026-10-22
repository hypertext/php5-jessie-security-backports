#!/bin/bash
# Usage: ./build.sh   Needs Docker; the .debs end up in dist/.
#   RUN_TESTS=1 ./build.sh   also runs the PHP test suite (much slower)
#   CPUS=8 ./build.sh        parallel jobs (default: 2)
set -euo pipefail
cd "$(dirname "$0")"
. ./sources.env

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }

fetch() {
    local file="$1" want="$2"
    if [ ! -f "sources/$file" ]; then
        local url="$ELTS_BASE/$(printf '%s' "$file" | sed 's/+/%2B/g')"
        curl -fsSL -o "sources/$file" "$url"
    fi
    [ "$(sha256 "sources/$file")" = "$want" ] || { echo "checksum mismatch: $file"; exit 1; }
}

mkdir -p sources dist
fetch "$DSC" "$DSC_SHA256"
fetch "$ORIG_TAR" "$ORIG_SHA256"
fetch "$DEBIAN_TAR" "$DEBIAN_SHA256"

opts="parallel=${CPUS:-2}"
[ -n "${RUN_TESTS:-}" ] || opts="$opts nocheck"

docker build --platform linux/amd64 -t php5-build-jessie docker/jessie
docker run --rm --platform linux/amd64 -e DEB_BUILD_OPTIONS="$opts" -v "$PWD:/work" \
    php5-build-jessie /work/scripts/debbuild.sh
