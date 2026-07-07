#!/usr/bin/env bash
set -euo pipefail

# GENERATED DEB PACKAGING METADATA - DO NOT EDIT IN deb-racket.
# Generated entrypoint: build-deb.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/deb-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/build-deb.sh --artifact-dir PATH --work-dir PATH --deb-system SYSTEM --deb-release RELEASE --deb-arch ARCH [options]

Build a binary .deb from a stable source archive. All mutable paths are named.

Options:
  --source-archive PATH  Local source archive to copy into the build work dir.
  --source-url URL       Source archive URL. Defaults to the generated release URL.
  --artifact-dir PATH    Directory that receives the final .deb.
  --work-dir PATH        Build work directory.
  --deb-system SYSTEM    debian12 or ubuntu2404.
  --deb-release RELEASE  Package revision base, for example 1. The system suffix is appended separately.
  --cache-mode MODE      postinstall or cached. Defaults to postinstall.
  --prefix PATH          Install prefix inside the package. Defaults to generated /usr.
  --deb-arch ARCH        amd64, x86_64, x64, arm64, or aarch64.
  --jobs N               Parallel jobs passed to make.
  --dry-run              Print checks and commands without writing outputs.
USAGE
}

DRY_RUN=0
SOURCE_ARCHIVE=
SOURCE_URL="$DEFAULT_SOURCE_URL"
SOURCE_URL_EXPLICIT=0
ARTIFACT_DIR=
WORK_DIR=
DEB_SYSTEM=
DEB_RELEASE=
DEB_ARCH=
JOBS=1
PREFIX="$DEFAULT_PREFIX"
CACHE_MODE="$DEFAULT_CACHE_MODE"

while [ $# -gt 0 ]; do
  case "$1" in
    --source-archive) [ $# -ge 2 ] || usage_error "missing value for --source-archive"; SOURCE_ARCHIVE="$2"; shift 2 ;;
    --source-url) [ $# -ge 2 ] || usage_error "missing value for --source-url"; SOURCE_URL="$2"; SOURCE_URL_EXPLICIT=1; shift 2 ;;
    --artifact-dir) [ $# -ge 2 ] || usage_error "missing value for --artifact-dir"; ARTIFACT_DIR="$2"; shift 2 ;;
    --work-dir) [ $# -ge 2 ] || usage_error "missing value for --work-dir"; WORK_DIR="$2"; shift 2 ;;
    --deb-system) [ $# -ge 2 ] || usage_error "missing value for --deb-system"; DEB_SYSTEM="$2"; shift 2 ;;
    --deb-release) [ $# -ge 2 ] || usage_error "missing value for --deb-release"; DEB_RELEASE="$2"; shift 2 ;;
    --cache-mode) [ $# -ge 2 ] || usage_error "missing value for --cache-mode"; CACHE_MODE="$2"; shift 2 ;;
    --prefix) [ $# -ge 2 ] || usage_error "missing value for --prefix"; PREFIX="$2"; shift 2 ;;
    --deb-arch) [ $# -ge 2 ] || usage_error "missing value for --deb-arch"; DEB_ARCH="$2"; shift 2 ;;
    --jobs) [ $# -ge 2 ] || usage_error "missing value for --jobs"; JOBS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

REPO_ROOT=$(repo_root_from_script)
require_repo_root "$REPO_ROOT"
[ -n "$ARTIFACT_DIR" ] || usage_error "--artifact-dir is required"
[ -n "$WORK_DIR" ] || usage_error "--work-dir is required"
[ -n "$DEB_SYSTEM" ] || usage_error "--deb-system is required"
[ -n "$DEB_RELEASE" ] || usage_error "--deb-release is required"
[ -n "$DEB_ARCH" ] || usage_error "--deb-arch is required"
validate_deb_system "$DEB_SYSTEM"
validate_deb_release "$DEB_RELEASE"
validate_cache_mode "$CACHE_MODE"
NORMALIZED_ARCH=$(normalize_arch "$DEB_ARCH")
PACKAGE_NAME=$(package_name_for_cache_mode "$CACHE_MODE")
CONFLICTING_PACKAGE_NAME=$(conflicting_package_name_for_cache_mode "$CACHE_MODE")
if [ -n "$SOURCE_ARCHIVE" ] && [ "$SOURCE_URL_EXPLICIT" = 1 ]; then
  usage_error "use either --source-archive or --source-url, not both"
fi

maybe_require_exe "$DRY_RUN" tar
maybe_require_exe "$DRY_RUN" make
maybe_require_exe "$DRY_RUN" dpkg-deb

SOURCE_WORK="$WORK_DIR/source"
SOURCE_PATH="$SOURCE_WORK/$SOURCE_ARCHIVE_NAME"
EXTRACT_ROOT="$WORK_DIR/source-tree"
STAGE_ROOT="$WORK_DIR/deb-root"
DEBIAN_DIR="$STAGE_ROOT/DEBIAN"
DEB_NAME=$(deb_name_for_arch "$NORMALIZED_ARCH" "$DEB_RELEASE" "$DEB_SYSTEM" "$CACHE_MODE")
DEB_VERSION=$(deb_package_version "$DEB_RELEASE" "$DEB_SYSTEM")

printf 'Repository root: %s\n' "$REPO_ROOT"
printf 'DEB system: %s\n' "$DEB_SYSTEM"
printf 'DEB release: %s\n' "$DEB_RELEASE"
printf 'DEB version: %s\n' "$DEB_VERSION"
printf 'DEB cache mode: %s\n' "$CACHE_MODE"
printf 'DEB package name: %s\n' "$PACKAGE_NAME"
printf 'Source archive: %s\n' "${SOURCE_ARCHIVE:-$SOURCE_URL}"
printf 'DEB output: %s\n' "$ARTIFACT_DIR/$DEB_NAME"

if [ "$DRY_RUN" = 0 ]; then
  reset_output_dir 0 "$SOURCE_WORK"
  reset_output_dir 0 "$EXTRACT_ROOT"
  reset_output_dir 0 "$STAGE_ROOT"
fi
prepare_source_archive "$DRY_RUN" "$SOURCE_ARCHIVE" "$SOURCE_URL" "$SOURCE_PATH"

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would extract source archive into: %s\n' "$EXTRACT_ROOT"
  printf 'Would build install root: %s\n' "$STAGE_ROOT"
  printf 'Would write Debian control metadata: %s\n' "$DEBIAN_DIR/control"
  printf 'Would configure cache mode: %s\n' "$CACHE_MODE"
  printf 'Would build DEB artifact: %s\n' "$ARTIFACT_DIR/$DEB_NAME"
  exit 0
fi

tar -xzf "$SOURCE_PATH" -C "$EXTRACT_ROOT"
mapfile -t source_dirs < <(find "$EXTRACT_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
if [ "${#source_dirs[@]}" -ne 1 ]; then
  printf 'Expected exactly one extracted source directory, got %s\n' "${#source_dirs[@]}" >&2
  printf '  %s\n' "${source_dirs[@]}" >&2
  exit 1
fi
SOURCE_DIR="${source_dirs[0]}"

sed -i 's|))$|) (default-scope . "installation") (compiled-file-cache-roots . (user system)) (compiled-file-system-cache-root . "/var/cache/racket/compiled"))|' "$SOURCE_DIR/etc/config.rktd"
sed -i 's/"1[.]1"/"3"/g' "$SOURCE_DIR/collects/openssl/libssl.rkt" "$SOURCE_DIR/collects/openssl/libcrypto.rkt"
cd "$SOURCE_DIR/src"
./configure \
  --disable-debug \
  --disable-dependency-tracking \
  --enable-origtree=no \
  --enable-sharezo \
  --prefix="$PREFIX" \
  --sysconfdir=/etc \
  --enable-useprefix
make -j"$JOBS"
make install DESTDIR="$STAGE_ROOT"
cd "$REPO_ROOT"
find "$STAGE_ROOT" -type d -name compiled ! -path '*/info-domain/compiled' -prune -exec rm -rf {} +
if [ "$CACHE_MODE" = cached ]; then
  build_staged_system_cache "$STAGE_ROOT" "$PREFIX"
fi

if ! find "$STAGE_ROOT" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  die "staged package root is empty: $STAGE_ROOT"
fi
mkdir -p "$DEBIAN_DIR"
cat > "$DEBIAN_DIR/control" <<CONTROL
Package: $PACKAGE_NAME
Version: $DEB_VERSION
Section: devel
Priority: optional
Architecture: $NORMALIZED_ARCH
Maintainer: $PACKAGE_MAINTAINER
Homepage: $PACKAGE_HOMEPAGE
Conflicts: $CONFLICTING_PACKAGE_NAME
Replaces: $CONFLICTING_PACKAGE_NAME
CONTROL
if [ "$CACHE_MODE" = cached ]; then
  cat >> "$DEBIAN_DIR/control" <<CONTROL
Provides: $BASE_PACKAGE_NAME
CONTROL
fi
cat >> "$DEBIAN_DIR/control" <<CONTROL
Depends: libc6, libedit2, libffi8, libssl3, libsqlite3-0, zlib1g
Description: $PACKAGE_SUMMARY
 Racket packaged from a stable source release archive.
CONTROL
if [ "$CACHE_MODE" = postinstall ]; then
cat > "$DEBIAN_DIR/postinst" <<'POSTINST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  raco setup --system --no-user --reset-cache -D --no-pkg-deps
  compiled_cache_root="/var/cache/racket/compiled"
  mkdir -p "$compiled_cache_root"
  empty_home=$(mktemp -d)
  if ! HOME="$empty_home" racket -U -R "$compiled_cache_root" -N rhombus -l- rhombus/run.rhm --version >/dev/null; then
    rm -rf "$empty_home"
    exit 1
  fi
  if ! HOME="$empty_home" racket -U -R "$compiled_cache_root" -N rhombus -l- rhombus/run.rhm -e 'println("package-racket-rhombus-cache")' >/dev/null; then
    rm -rf "$empty_home"
    exit 1
  fi
  rm -rf "$empty_home"
fi
exit 0
POSTINST
else
cat > "$DEBIAN_DIR/postinst" <<'POSTINST'
#!/bin/sh
set -e
exit 0
POSTINST
fi
chmod 755 "$DEBIAN_DIR/postinst"

if [ "$CACHE_MODE" = postinstall ]; then
cat > "$DEBIAN_DIR/prerm" <<'PRERM'
#!/bin/sh
set -e
package_present() {
  dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^i'
}
if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
  if ! package_present "racket9-cached"; then
    if command -v raco >/dev/null 2>&1; then
      raco setup --system --delete-cache || true
    fi
    rm -rf /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral/demod
    rmdir /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled 2>/dev/null || true
  fi
fi
exit 0
PRERM
else
cat > "$DEBIAN_DIR/prerm" <<'PRERM'
#!/bin/sh
set -e
exit 0
PRERM
fi
chmod 755 "$DEBIAN_DIR/prerm"
cat > "$DEBIAN_DIR/postrm" <<'POSTRM'
#!/bin/sh
set -e
OTHER_RACKET_PACKAGE='@OTHER_RACKET_PACKAGE@'
package_present() {
  dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^i'
}
other_racket_package_present() {
  package_present "$OTHER_RACKET_PACKAGE"
}
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
  if ! other_racket_package_present; then
    rm -rf /var/cache/racket/compiled
    rm -rf /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral/demod
    rmdir /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled 2>/dev/null || true
  fi
fi
exit 0
POSTRM
sed -i "s|@OTHER_RACKET_PACKAGE@|$CONFLICTING_PACKAGE_NAME|g" "$DEBIAN_DIR/postrm"
chmod 755 "$DEBIAN_DIR/postrm"

(cd "$STAGE_ROOT" && find . -type f ! -path './DEBIAN/*' -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums)
require_nonempty_file "$DEBIAN_DIR/control"
require_nonempty_file "$DEBIAN_DIR/postinst"
require_nonempty_file "$DEBIAN_DIR/prerm"
require_nonempty_file "$DEBIAN_DIR/postrm"
require_nonempty_file "$DEBIAN_DIR/md5sums"
mkdir -p "$ARTIFACT_DIR"
dpkg-deb --root-owner-group --build "$STAGE_ROOT" "$ARTIFACT_DIR/$DEB_NAME"
"$REPO_ROOT/scripts/verify-deb.sh" --deb "$ARTIFACT_DIR/$DEB_NAME" --deb-system "$DEB_SYSTEM" --deb-release "$DEB_RELEASE" --deb-arch "$NORMALIZED_ARCH" --cache-mode "$CACHE_MODE"
printf 'DEB package: %s\n' "$ARTIFACT_DIR/$DEB_NAME"
