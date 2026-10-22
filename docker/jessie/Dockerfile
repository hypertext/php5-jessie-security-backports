# Debian 8 (jessie) build environment. debian/eol:jessie already points to
# archive.debian.org, whose Release files expired long ago.
FROM debian/eol:jessie

RUN printf 'Acquire::Check-Valid-Until "false";\nAPT::Get::Assume-Yes "true";\nAPT::Install-Recommends "false";\n' \
      > /etc/apt/apt.conf.d/99archive \
 && apt-get update \
 && apt-get install build-essential devscripts equivs fakeroot quilt \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
