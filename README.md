# php5-jessie-security-backports

PHP 5.6.40 for Debian 8 (jessie): the last php5 package of [Freexian Extended LTS](https://www.freexian.com/lts/extended/)
(`5.6.40+dfsg-0+deb8u23`, April 2025) plus the 2026 security fixes from the php5.6 patch series that
[Ondřej Surý](https://deb.sury.org/) maintains, including the fix for CVE-2026-109618 and CVE-2026-109619
("Avoid state corruption via bailout").

Neither source is complete on its own: ELTS carries 2025 fixes that the sury series lacks (CVE-2025-1217, -1219,
-1734, -1736, -1861), and the sury series carries the 2026 fixes that ELTS lacks. This repository adds the missing
2026 patches on top of ELTS.

Upstream PHP 5.6 has been end of life since 2019, Debian 8 since 2020. These packages exist for legacy hosts that
cannot move yet. Plan your migration anyway.

## Added fixes

| Patch | Fix |
| --- | --- |
| `0253` | CVE-2026-7261: use-after-free after header parsing failure with `SOAP_PERSISTENCE_SESSION` |
| `0254` | CVE-2026-7262: broken NULL check for Apache map values in SOAP |
| `0257` | CVE-2026-6735: XSS in the FPM status endpoint |
| `0260` | GH-22186: heap overflow in `openssl_encrypt()` with AES-WRAP-PAD (no effect with jessie's OpenSSL 1.0.1, which has no wrap mode) |
| `0261` | CVE-2026-109618, CVE-2026-109619: state corruption via bailout |

The patches are taken from the `5.6.40-104` series on packages.sury.org and refreshed to apply without fuzz on
the jessie source (NEWS hunks dropped). Each patch keeps its upstream header and notes its origin.

## Behaviour changes

Both come from `0261` and match the sury packages:

* **Memory limit and size overflow errors end the process immediately.** The message goes to stderr and the process
  exits with status 1. No entry in the PHP error log, no shutdown functions, no session write, no error page: the
  client gets an empty response. With mod_php the message lands in the Apache error log; with FPM only if the pool
  has `catch_workers_output = yes`.
* **`session.upload_progress` is disabled.** Regular file uploads are not affected.

## Packages

The same 34 binary packages as Debian's php5 source package (`php5-cli`, `libapache2-mod-php5`, `php5-fpm`,
`php5-mysql`, `php5-gd`, …), as drop-in replacements. Version `5.6.40+dfsg-0+deb8u23+local1` sorts above
ELTS `deb8u23`, so a later ELTS update would replace it again.

Dependencies are identical to the last Debian LTS build `deb8u12` for 33 of the 34 packages, so installation needs
no working APT sources and works on old point releases (tested on 8.5). The exception is `php5-snmp`, which needs
`libsnmp30 (>= 5.7.2.1+dfsg-1+deb8u6~dfsg)` from ELTS.

## Installing

Replace only the packages that are installed (`dpkg -l 'php5*' libapache2-mod-php5 php-pear`). Install
`php5-common` **first**: the maintainer scripts of the other packages use its helpers, and the helpers of older
versions make `dpkg -i *.deb` fail with "pre-removal script returned error exit status 1".

```sh
dpkg -i --force-confold php5-common_*.deb
dpkg -i --force-confold php5-cli_*.deb libapache2-mod-php5_*.deb php5-mysql_*.deb   # … whatever is installed
dpkg --audit                     # must print nothing
service apache2 restart          # or: service php5-fpm restart
```

`--force-confold` keeps your `php.ini` files. Afterwards the Apache parent must not map a deleted module:

```sh
grep libphp5 /proc/$(pgrep -o apache2)/maps    # no "(deleted)"
```

## Verifying

```sh
php -d memory_limit=4M -r 'register_shutdown_function(function(){echo "SHUTDOWN\n";}); $a=str_repeat("x",8*1024*1024);'; echo "rc=$?"
```

Fixed: the "Allowed memory size" message, no `SHUTDOWN`, `rc=1`. Unfixed: `SHUTDOWN` is printed, `rc=255`.

## Rolling back

Keep the previous packages before upgrading. If they are gone from `/var/cache/apt/archives/`, the last Debian LTS
build (`deb8u12`) is still on
[archive.debian.org](https://archive.debian.org/debian-security/pool/updates/main/p/php5/), and ELTS subscribers can
install `deb8u23` from Freexian. Install them with `dpkg -i --force-confold` and restart the web server.

## Building

Requires Docker. The script downloads the ELTS source package from deb.freexian.com, checks its SHA-256 against
`sources.env`, then builds the packages in a `debian/eol:jessie` container and smoke-tests them (version and the
bailout behaviour above).

```sh
./build.sh                 # without the PHP test suite
RUN_TESTS=1 ./build.sh     # with it (much slower)
CPUS=8 ./build.sh          # parallel jobs, default 2
```

The packages, `SHA256SUMS` and the build log end up in `dist/`. On a jessie host or VM, `scripts/debbuild.sh <repo dir>`
does the same without Docker (as root, after placing the sources in `sources/`).

## Testing

* Full PHP test suite compared with the unmodified ELTS `deb8u23` built in the same VM: 10 additional failures, all
  explained. `tests/lang/bug45392` and eight `ext/session/tests/rfc1867*` tests expect the old behaviour described
  above; `ext/soap/tests/GHSA-m33r-qmcv-p97q` needs `/var/lib/php5/sessions`, which the build environment lacks (it
  passes once the directory exists).
* An independent review checked every hunk against the jessie source: all hunks land in the intended functions, no
  ELTS fix is reverted.
* In production on a Debian 8.5 host with Apache and mod_php.

## Notes

* **No maintenance promised.** This is a snapshot as of 2026-10-21. There may be no updates for later PHP 5.6
  backports.
* Left out on purpose: `0251-Add-minimal-privacy-preserving-secure-DNS-telemetry-.patch` (not a security fix, adds
  network activity, pulls in libsodium) and `0255` (test files only).
* Only PHP is patched. The rest of a jessie system (OpenSSL, Apache, libxml2, …) needs its own updates, e.g. from
  Freexian ELTS.
* Not affiliated with or supported by Freexian, deb.sury.org or the PHP project. All credit for the backports goes to
  the PHP developers, Ondřej Surý, the Debian PHP maintainers and the Freexian ELTS team. Inspired by
  [denizkoekden/php56-el-backports](https://github.com/denizkoekden/php56-el-backports), which does the same for
  CentOS/RHEL 6 and 7.

## License

The build scripts and documentation in this repository are released into the public domain under the
[Unlicense](UNLICENSE). The patches in `debian/patches/` are derived from PHP and stay under the PHP License 3.01;
the Debian packaging keeps the licenses listed in `debian/copyright` of the source package.
