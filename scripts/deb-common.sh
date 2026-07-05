#!/usr/bin/env bash
set -euo pipefail

# GENERATED DEB PACKAGING METADATA - DO NOT EDIT IN deb-racket.
# Generated entrypoint: deb-common.sh

BASE_PACKAGE_NAME='racket9'
CACHED_PACKAGE_NAME='racket9-cached'
PACKAGE_NAME="$BASE_PACKAGE_NAME"
PACKAGE_VERSION='9.2.2'
PACKAGE_SOURCE_VERSION='9.2.2'
DEFAULT_DEB_SYSTEM='ubuntu2404'
DEFAULT_DEB_RELEASE='2'
DEFAULT_DEB_ARCH='amd64'
DEFAULT_PREFIX='/usr'
DEFAULT_CACHE_MODE=postinstall
SOURCE_ARCHIVE_NAME='racket-minimal-9.2.2-src.tgz'
DEFAULT_SOURCE_URL='https://github.com/CutieDeng/racket/releases/download/v9.2.2/racket-minimal-9.2.2-src.tgz'
SOURCE_SHA256='fc25e3ca9996f96b41edac3ab2d1517a8c42e2d0ed9107b81252bcd62895669e'
PACKAGE_SUMMARY='Racket programming language'
PACKAGE_MAINTAINER='Cutie Deng <cutiedeng@users.noreply.github.com>'
PACKAGE_HOMEPAGE='https://racket-lang.org/'

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  die "$1. Run with --help for usage."
}

repo_root_from_script() {
  local script_dir
  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  CDPATH= cd -- "$script_dir/.." && pwd
}

require_repo_root() {
  local root="$1"
  [ -d "$root" ] || die "repository root does not exist: $root"
  [ -f "$root/scripts/deb-common.sh" ] || die "missing common script: $root/scripts/deb-common.sh"
  [ -f "$root/SOURCES/.gitkeep" ] || die "missing source placeholder: $root/SOURCES/.gitkeep"
}

require_file() {
  [ -f "$1" ] || die "file does not exist: $1"
}

require_nonempty_file() {
  require_file "$1"
  [ -s "$1" ] || die "file is empty: $1"
}

require_dir() {
  [ -d "$1" ] || die "directory does not exist: $1"
}

require_absolute_path() {
  case "$1" in
    /*) ;;
    *) die "$2 must be an absolute path: $1" ;;
  esac
}

require_exe() {
  command -v "$1" >/dev/null 2>&1 || die "executable not found in PATH: $1"
}

maybe_require_exe() {
  local dry_run="$1"
  local exe="$2"
  if [ "$dry_run" = 1 ]; then
    printf 'Would require executable: %s\n' "$exe"
  else
    require_exe "$exe"
  fi
}

run_cmd() {
  local dry_run="$1"
  shift
  printf '$'
  printf ' %q' "$@"
  printf '\n'
  if [ "$dry_run" = 0 ]; then
    "$@"
  fi
}

normalize_arch() {
  case "$1" in
    amd64|x86_64|x64) printf 'amd64\n' ;;
    arm64|aarch64) printf 'arm64\n' ;;
    *) die "deb arch must be amd64, x86_64, x64, arm64, or aarch64: $1" ;;
  esac
}

validate_deb_system() {
  case "$1" in
    debian12|ubuntu2404) ;;
    *) die "deb system must be debian12 or ubuntu2404: $1" ;;
  esac
}

validate_deb_release() {
  local release="$1"
  [ -n "$release" ] || die "deb release is required"
  case "$release" in
    *.*) die "deb release must not contain . because system is appended separately: $release" ;;
    [0-9]*) ;;
    *) die "deb release must start with a digit: $release" ;;
  esac
  case "$release" in
    *[!A-Za-z0-9_+~-]*) die "deb release contains unsupported characters: $release" ;;
  esac
}

validate_cache_mode() {
  case "$1" in
    postinstall|cached) ;;
    *) die "cache mode must be postinstall or cached: $1" ;;
  esac
}

package_name_for_cache_mode() {
  local mode="$1"
  validate_cache_mode "$mode"
  case "$mode" in
    postinstall) printf '%s\n' "$BASE_PACKAGE_NAME" ;;
    cached) printf '%s\n' "$CACHED_PACKAGE_NAME" ;;
  esac
}

conflicting_package_name_for_cache_mode() {
  local mode="$1"
  validate_cache_mode "$mode"
  case "$mode" in
    postinstall) printf '%s\n' "$CACHED_PACKAGE_NAME" ;;
    cached) printf '%s\n' "$BASE_PACKAGE_NAME" ;;
  esac
}

deb_full_release() {
  local release="$1"
  local system="$2"
  printf '%s.%s\n' "$release" "$system"
}

deb_package_version() {
  local release="$1"
  local system="$2"
  printf '%s-%s\n' "$PACKAGE_VERSION" "$(deb_full_release "$release" "$system")"
}

deb_name_for_arch() {
  local arch="$1"
  local release="$2"
  local system="$3"
  local mode="${4:-$DEFAULT_CACHE_MODE}"
  local package_name
  package_name=$(package_name_for_cache_mode "$mode")
  printf '%s_%s_%s.deb\n' "$package_name" "$(deb_package_version "$release" "$system")" "$arch"
}

find_staged_config_dir() {
  local stage_root="$1"
  local prefix="$2"
  local candidate
  for candidate in "$stage_root/etc/racket" "$stage_root$prefix/etc/racket"; do
    if [ -f "$candidate/config.rktd" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  die "could not find staged Racket config.rktd under $stage_root"
}

find_staged_racket() {
  local stage_root="$1"
  local prefix="$2"
  local candidate
  for candidate in "$stage_root$prefix/bin/racket" "$stage_root/bin/racket"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  die "could not find staged racket executable under $stage_root"
}

replace_config_cache_root() {
  local config_file="$1"
  local from="$2"
  local to="$3"
  local escaped_from escaped_to
  escaped_from=$(printf '%s\n' "$from" | sed 's/[&|]/\\&/g')
  escaped_to=$(printf '%s\n' "$to" | sed 's/[&|]/\\&/g')
  grep -F "$from" "$config_file" >/dev/null \
    || die "config does not contain expected cache root $from: $config_file"
  sed -i "s|$escaped_from|$escaped_to|g" "$config_file"
}

require_staged_system_cache() {
  local stage_root="$1"
  local cache_root="$stage_root/var/cache/racket/compiled"
  if ! find "$cache_root" -path '*/compiled/*.zo' -type f -print -quit 2>/dev/null | grep -q .; then
    die "staged system compiled cache is empty: $cache_root"
  fi
}

build_staged_system_cache() {
  local stage_root="$1"
  local prefix="$2"
  local runtime_cache_root="/var/cache/racket/compiled"
  local staged_cache_root="$stage_root$runtime_cache_root"
  local config_dir config_file racket_bin backup
  config_dir=$(find_staged_config_dir "$stage_root" "$prefix")
  config_file="$config_dir/config.rktd"
  racket_bin=$(find_staged_racket "$stage_root" "$prefix")
  backup="$config_file.package-racket-cache-backup"
  cp "$config_file" "$backup"
  replace_config_cache_root "$config_file" "$runtime_cache_root" "$staged_cache_root"
  mkdir -p "$staged_cache_root"
  if ! "$racket_bin" -G "$config_dir" -N raco -l- raco setup --system --no-user --reset-cache -D --no-pkg-deps; then
    cp "$backup" "$config_file"
    rm -f "$backup"
    return 1
  fi
  cp "$backup" "$config_file"
  rm -f "$backup"
  require_staged_system_cache "$stage_root"
}

reset_output_dir() {
  local dry_run="$1"
  local path="$2"
  require_absolute_path "$path" "output directory"
  if [ "$path" = / ]; then
    die "refusing to reset / as output directory"
  fi
  if [ "$dry_run" = 1 ]; then
    printf 'Would reset output directory: %s\n' "$path"
  else
    rm -rf "$path"
    mkdir -p "$path"
  fi
}

validate_source_archive() {
  local dry_run="$1"
  local archive="$2"
  local expected_root="racket-$PACKAGE_SOURCE_VERSION"
  if [ "$dry_run" = 1 ]; then
    printf 'Would validate source archive: %s\n' "$archive"
    return
  fi
  require_nonempty_file "$archive"
  tar -tzf "$archive" "$expected_root/src/configure" >/dev/null \
    || die "source archive missing $expected_root/src/configure: $archive"
  tar -tzf "$archive" "$expected_root/collects/racket/main.rkt" >/dev/null \
    || die "source archive missing $expected_root/collects/racket/main.rkt: $archive"
}

verify_source_sha256() {
  local dry_run="$1"
  local archive="$2"
  if [ -z "$SOURCE_SHA256" ]; then
    printf 'No generated source sha256 is pinned; skipping source sha256 check.\n'
    return
  fi
  if [ "$dry_run" = 1 ]; then
    printf 'Would verify source sha256: %s\n' "$SOURCE_SHA256"
    return
  fi
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$archive" | cut -d ' ' -f 1)
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$archive" | cut -d ' ' -f 1)
  else
    die "executable not found in PATH: sha256sum or shasum"
  fi
  [ "$actual" = "$SOURCE_SHA256" ] \
    || die "source sha256 mismatch: expected $SOURCE_SHA256 but got $actual"
}

prepare_source_archive() {
  local dry_run="$1"
  local source_archive="$2"
  local source_url="$3"
  local dest="$4"
  require_absolute_path "$dest" "source archive destination"
  if [ "$dry_run" = 0 ]; then
    mkdir -p "$(dirname "$dest")"
  fi
  if [ -n "$source_archive" ]; then
    require_nonempty_file "$source_archive"
    run_cmd "$dry_run" cp "$source_archive" "$dest"
  else
    [ -n "$source_url" ] || die "source URL is empty"
    maybe_require_exe "$dry_run" curl
    run_cmd "$dry_run" curl -fL --retry 3 --output "$dest" "$source_url"
  fi
  validate_source_archive "$dry_run" "$dest"
  verify_source_sha256 "$dry_run" "$dest"
}
