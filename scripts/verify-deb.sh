#!/usr/bin/env bash
set -euo pipefail

# GENERATED DEB PACKAGING METADATA - DO NOT EDIT IN deb-racket.
# Generated entrypoint: verify-deb.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/deb-common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/verify-deb.sh --deb PATH --deb-system SYSTEM --deb-release RELEASE --deb-arch ARCH [--cache-mode MODE] [--dry-run]

Validate .deb filename and metadata.
USAGE
}

DRY_RUN=0
DEB_PATH=
DEB_SYSTEM=
DEB_RELEASE=
DEB_ARCH=
CACHE_MODE="$DEFAULT_CACHE_MODE"

while [ $# -gt 0 ]; do
  case "$1" in
    --deb) [ $# -ge 2 ] || usage_error "missing value for --deb"; DEB_PATH="$2"; shift 2 ;;
    --deb-system) [ $# -ge 2 ] || usage_error "missing value for --deb-system"; DEB_SYSTEM="$2"; shift 2 ;;
    --deb-release) [ $# -ge 2 ] || usage_error "missing value for --deb-release"; DEB_RELEASE="$2"; shift 2 ;;
    --deb-arch) [ $# -ge 2 ] || usage_error "missing value for --deb-arch"; DEB_ARCH="$2"; shift 2 ;;
    --cache-mode) [ $# -ge 2 ] || usage_error "missing value for --cache-mode"; CACHE_MODE="$2"; shift 2 ;;
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
validate_cache_mode "$CACHE_MODE"
NORMALIZED_ARCH=$(normalize_arch "$DEB_ARCH")
PACKAGE_NAME=$(package_name_for_cache_mode "$CACHE_MODE")
DEB_VERSION=$(deb_package_version "$DEB_RELEASE" "$DEB_SYSTEM" "$CACHE_MODE")
EXPECTED_DEB=$(deb_name_for_arch "$NORMALIZED_ARCH" "$DEB_RELEASE" "$DEB_SYSTEM" "$CACHE_MODE")

if [ "$DRY_RUN" = 1 ]; then
  printf 'Would verify DEB: %s\n' "$DEB_PATH"
  printf 'Would expect DEB basename: %s\n' "$EXPECTED_DEB"
  printf 'Would expect DEB version: %s\n' "$DEB_VERSION"
  printf 'Would expect DEB cache mode: %s\n' "$CACHE_MODE"
  printf 'Would expect DEB package name: %s\n' "$PACKAGE_NAME"
  exit 0
fi

require_exe dpkg-deb
require_exe tar
require_nonempty_file "$DEB_PATH"
[ "$(basename "$DEB_PATH")" = "$EXPECTED_DEB" ] || die "DEB basename does not match expected $EXPECTED_DEB: $DEB_PATH"

package=$(dpkg-deb --field "$DEB_PATH" Package)
version=$(dpkg-deb --field "$DEB_PATH" Version)
arch=$(dpkg-deb --field "$DEB_PATH" Architecture)
conflicts=$(dpkg-deb --field "$DEB_PATH" Conflicts)
replaces=$(dpkg-deb --field "$DEB_PATH" Replaces)
provides=$(dpkg-deb --field "$DEB_PATH" Provides)
[ "$package" = "$PACKAGE_NAME" ] || die "DEB Package field mismatch: expected $PACKAGE_NAME got $package"
[ "$version" = "$DEB_VERSION" ] || die "DEB Version field mismatch: expected $DEB_VERSION got $version"
[ "$arch" = "$NORMALIZED_ARCH" ] || die "DEB Architecture field mismatch: expected $NORMALIZED_ARCH got $arch"
[ "$conflicts" = "$LEGACY_CACHED_PACKAGE_NAME" ] || die "DEB does not conflict with the legacy split-name cached package: $conflicts"
[ "$replaces" = "$LEGACY_CACHED_PACKAGE_NAME" ] || die "DEB does not replace the legacy split-name cached package: $replaces"
[ "$provides" = "$LEGACY_CACHED_PACKAGE_NAME (= $DEB_VERSION)" ] || die "DEB does not provide the legacy split-name cached package: $provides"
contents=$(dpkg-deb --contents "$DEB_PATH")
control_files=$(dpkg-deb --ctrl-tarfile "$DEB_PATH" | tar -tf -)
if printf '%s\n' "$contents" | grep -E '(^|[[:space:]])\./var/cache/racket/racket-compiled-cache[.]log$' >/dev/null; then
  die "DEB payload unexpectedly includes racket compiled cache debug log"
fi
for script in ./postinst ./prerm ./postrm; do
  printf '%s\n' "$control_files" | grep -Fx "$script" >/dev/null \
    || die "DEB control archive missing $script"
done
postinst_content=$(dpkg-deb --ctrl-tarfile "$DEB_PATH" | tar -xOf - ./postinst)
if [ "$CACHE_MODE" = postinstall ]; then
  printf '%s\n' "$postinst_content" | grep -F 'raco setup --system --no-user --reset-cache -D --no-pkg-deps --no-launcher' >/dev/null \
    || die "DEB postinst does not build the system compiled cache"
  printf '%s\n' "$postinst_content" | grep -F 'package-racket-rhombus-cache' >/dev/null \
    || die "DEB postinst does not warm the Rhombus demod cache"
  printf '%s\n' "$postinst_content" | grep -F 'PLTCOMPILEDROOTS="$compiled_cache_root" rhombus --version' >/dev/null \
    || die "DEB postinst does not warm the Rhombus version cache into the system cache"
  if printf '%s\n' "$contents" | grep -E '(^|[[:space:]])\./var/cache/racket/compiled/.+[.]zo$' >/dev/null; then
    die "postinstall DEB payload unexpectedly includes system compiled cache .zo files"
  fi
else
  if printf '%s\n' "$postinst_content" | grep -F 'raco setup --system --no-user --reset-cache -D --no-pkg-deps' >/dev/null; then
    die "cached DEB postinst unexpectedly builds the system compiled cache"
  fi
  printf '%s\n' "$contents" | grep -E '(^|[[:space:]])\./var/cache/racket/compiled/.+[.]zo$' >/dev/null \
    || die "cached DEB payload does not include system compiled cache .zo files"
  runtime_collects_cache="./var/cache/racket/compiled/${DEFAULT_PREFIX#/}/share/racket/collects"
  printf '%s\n' "$contents" | grep -F "$runtime_collects_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include runtime-keyed collects cache .zo files"
  runtime_pkgs_cache="./var/cache/racket/compiled/${DEFAULT_PREFIX#/}/share/racket/pkgs"
  printf '%s\n' "$contents" | grep -F "$runtime_pkgs_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include runtime-keyed package cache .zo files"
  rhombus_ephemeral_cache="./${DEFAULT_PREFIX#/}/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral/demod"
  printf '%s\n' "$contents" | grep -F "$rhombus_ephemeral_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include Rhombus demod cache .zo files"
  runtime_rhombus_collects_cache="$rhombus_ephemeral_cache/linklet/${DEFAULT_PREFIX#/}/share/racket/collects"
  printf '%s\n' "$contents" | grep -F "$runtime_rhombus_collects_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include runtime-keyed Rhombus demod collects cache .zo files"
  runtime_rhombus_pkgs_cache="$rhombus_ephemeral_cache/linklet/${DEFAULT_PREFIX#/}/share/racket/pkgs"
  printf '%s\n' "$contents" | grep -F "$runtime_rhombus_pkgs_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include runtime-keyed Rhombus demod package cache .zo files"
  runtime_rhombus_native_collects_cache="$rhombus_ephemeral_cache/native/${DEFAULT_PREFIX#/}/share/racket/collects"
  printf '%s\n' "$contents" | grep -F "$runtime_rhombus_native_collects_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include runtime-keyed Rhombus demod native collects cache .zo files"
  runtime_rhombus_native_pkgs_cache="$rhombus_ephemeral_cache/native/${DEFAULT_PREFIX#/}/share/racket/pkgs"
  printf '%s\n' "$contents" | grep -F "$runtime_rhombus_native_pkgs_cache/" | grep -E '[.]zo$' >/dev/null \
    || die "cached DEB payload does not include runtime-keyed Rhombus demod native package cache .zo files"
  if printf '%s\n' "$contents" | grep -F "$rhombus_ephemeral_cache/" | grep -F '/deb-root/' >/dev/null; then
    die "cached DEB payload includes buildroot-keyed Rhombus demod cache paths"
  fi
fi
prerm_content=$(dpkg-deb --ctrl-tarfile "$DEB_PATH" | tar -xOf - ./prerm)
if [ "$CACHE_MODE" = postinstall ]; then
  printf '%s\n' "$prerm_content" | grep -F 'raco setup --system --delete-cache' >/dev/null \
    || die "DEB prerm does not delete the system compiled cache"
else
  if printf '%s\n' "$prerm_content" | grep -F 'raco setup --system --delete-cache' >/dev/null; then
    die "cached DEB prerm unexpectedly deletes the system compiled cache through raco"
  fi
fi
postrm_content=$(dpkg-deb --ctrl-tarfile "$DEB_PATH" | tar -xOf - ./postrm)
printf '%s\n' "$postrm_content" | grep -F 'rm -rf /var/cache/racket/compiled' >/dev/null \
  || die "DEB postrm does not purge the system compiled cache directory"
printf '%s\n' "$postrm_content" | grep -F 'rhombus-lib/rhombus/private/compiled/ephemeral/demod' >/dev/null \
  || die "DEB postrm does not purge the Rhombus demod cache directory"
printf '%s\n' "$postrm_content" | grep -F 'rmdir /usr/share/racket/pkgs/rhombus-lib/rhombus/private/compiled/ephemeral' >/dev/null \
  || die "DEB postrm does not remove empty Rhombus ephemeral cache parents"
printf 'Validated DEB: %s\n' "$DEB_PATH"
