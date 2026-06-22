#!/usr/bin/env bash
set -euo pipefail

# GENERATED DEB PACKAGING METADATA - DO NOT EDIT IN deb-racket.
# Generated entrypoint: verify-deb.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/deb-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/verify-deb.sh --deb PATH --deb-system SYSTEM --deb-release RELEASE --deb-arch ARCH [--dry-run]

Validate .deb filename and metadata.
USAGE
}

DRY_RUN=0
DEB_PATH=
DEB_SYSTEM=
DEB_RELEASE=
DEB_ARCH=

while [ $# -gt 0 ]; do
  case "$1" in
    --deb) [ $# -ge 2 ] || usage_error "missing value for --deb"; DEB_PATH="$2"; shift 2 ;;
    --deb-system) [ $# -ge 2 ] || usage_error "missing value for --deb-system"; DEB_SYSTEM="$2"; shift 2 ;;
    --deb-release) [ $# -ge 2 ] || usage_error "missing value for --deb-release"; DEB_RELEASE="$2"; shift 2 ;;
    --deb-arch) [ $# -ge 2 ] || usage_error "missing value for --deb-arch"; DEB_ARCH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help) usage; exit 0 ;;
    *) usage_error "unknown option: $1" ;;
  esac
done

REPO_ROOT=$(repo_root_from_script)
require_repo_root "$REPO_ROOT"
[ -n "$DEB_PATH" ] || usage_error "--deb is required"
[ -n "$DEB_SYSTEM" ] || usage_error "--deb-system is required"
[ -n "$DEB_RELEASE" ] || usage_error "--deb-release is required"
[ -n "$DEB_ARCH" ] || usage_error "--deb-arch is required"
validate_deb_system "$DEB_SYSTEM"
validate_deb_release "$DEB_RELEASE"
NORMALIZED_ARCH=$(normalize_arch "$DEB_ARCH")
DEB_VERSION=$(deb_package_version "$DEB_RELEASE" "$DEB_SYSTEM")
EXPECTED_DEB=$(deb_name_for_arch "$NORMALIZED_ARCH" "$DEB_RELEASE" "$DEB_SYSTEM")

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would verify DEB: %s\n' "$DEB_PATH"
  printf 'Would expect DEB basename: %s\n' "$EXPECTED_DEB"
  printf 'Would expect DEB version: %s\n' "$DEB_VERSION"
  exit 0
fi

require_exe dpkg-deb
require_nonempty_file "$DEB_PATH"
[ "$(basename "$DEB_PATH")" = "$EXPECTED_DEB" ] || die "DEB basename does not match expected $EXPECTED_DEB: $DEB_PATH"

package=$(dpkg-deb --field "$DEB_PATH" Package)
version=$(dpkg-deb --field "$DEB_PATH" Version)
arch=$(dpkg-deb --field "$DEB_PATH" Architecture)
[ "$package" = "$PACKAGE_NAME" ] || die "DEB Package field mismatch: expected $PACKAGE_NAME got $package"
[ "$version" = "$DEB_VERSION" ] || die "DEB Version field mismatch: expected $DEB_VERSION got $version"
[ "$arch" = "$NORMALIZED_ARCH" ] || die "DEB Architecture field mismatch: expected $NORMALIZED_ARCH got $arch"
dpkg-deb --contents "$DEB_PATH" >/dev/null
printf 'Validated DEB: %s\n' "$DEB_PATH"
