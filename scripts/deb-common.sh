#!/usr/bin/env bash
set -euo pipefail

# GENERATED DEB PACKAGING METADATA - DO NOT EDIT IN deb-racket.
# Generated entrypoint: deb-common.sh

PACKAGE_NAME='racket9'
PACKAGE_VERSION='9.2.1'
PACKAGE_SOURCE_VERSION='9.2.1'
DEFAULT_DEB_SYSTEM='ubuntu2404'
DEFAULT_DEB_RELEASE='3'
DEFAULT_DEB_ARCH='amd64'
DEFAULT_PREFIX='/usr'
SOURCE_ARCHIVE_NAME='racket-minimal-9.2.1-src.tgz'
DEFAULT_SOURCE_URL='https://github.com/CutieDeng/racket/releases/download/v9.2.1/racket-minimal-9.2.1-src.tgz'
SOURCE_SHA256='b1b444059a00d41aebac94da8941eb45465aba8637eb8826058e40cc1e79eebc'
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
  printf '%s_%s_%s.deb\n' "$PACKAGE_NAME" "$(deb_package_version "$release" "$system")" "$arch"
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
