#!/bin/bash
# Builds and smoke-tests the patched php5 packages. Runs as root on Debian 8 (jessie):
# inside the container started by build.sh, or directly on a jessie host.
#   scripts/debbuild.sh [repo dir]   (default: /work); sources/ and dist/ live in the repo dir
set -euo pipefail
repo=$(readlink -f "${1:-/work}")
. "$repo/sources.env"

# Not below /root: the test suite starts a MySQL instance that needs access.
build=$(mktemp -d /var/tmp/php5-build.XXXXXX)
chmod 755 "$build"
cd "$build"

cp "$repo/sources/$DSC" "$repo/sources/$ORIG_TAR" "$repo/sources/$DEBIAN_TAR" .
dpkg-source -x "$DSC"
cd php5-5.6.40+dfsg

# Append the backports to the ELTS series; dpkg-source applies them before the build.
mkdir -p debian/patches/sury-2026
for p in "$repo"/debian/patches/*.patch; do
    cp "$p" debian/patches/sury-2026/
    echo "sury-2026/$(basename "$p")" >> debian/patches/series
done
cat "$repo/debian/changelog.entry" debian/changelog > debian/changelog.new
mv debian/changelog.new debian/changelog

apt-get update
mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control
rm -f php5-build-deps_*

mkdir -p "$repo/dist"
dpkg-buildpackage -us -uc 2>&1 | tee "$repo/dist/build.log"
cd ..
cp *.deb *+local1.dsc *+local1.debian.tar.xz *.changes "$repo/dist/"
(cd "$repo/dist" && sha256sum *.deb > SHA256SUMS)

# Smoke test; apt pulls in what a fresh system lacks (lsof, psmisc, php5-json, …).
dpkg -i php5-common_*.deb php5-cli_*.deb || apt-get -y -f install
php5 -v | grep -q '+local1'
# CVE-2026-109618/109619: an out-of-memory error must end the process without running PHP code again.
set +e
res=$(php5 -n -d memory_limit=4M -r 'register_shutdown_function(function(){echo "SHUTDOWN";}); $a=str_repeat("x",8*1024*1024);' 2>/dev/null)
rc=$?
set -e
[ "$rc" = 1 ] && [ "${res#*SHUTDOWN}" = "$res" ] || { echo "smoke test failed: rc=$rc"; exit 1; }

echo "OK: $(ls "$repo"/dist/*.deb | wc -l) packages in dist/"
