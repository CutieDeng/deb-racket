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
DEFAULT_DEB_RELEASE='3'
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

find_staged_collects_dir() {
  local stage_root="$1"
  local prefix="$2"
  local candidate
  for candidate in "$stage_root$prefix/share/racket/collects" "$stage_root/usr/share/racket/collects"; do
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  die "could not find staged Racket collects under $stage_root"
}

require_staged_system_cache() {
  local stage_root="$1"
  local prefix="$2"
  local cache_root="$stage_root/var/cache/racket/compiled"
  local runtime_collects_dir="$prefix/share/racket/collects"
  local runtime_pkgs_dir="$prefix/share/racket/pkgs"
  local runtime_collects_cache="$cache_root/${runtime_collects_dir#/}"
  local runtime_pkgs_cache="$cache_root/${runtime_pkgs_dir#/}"
  if ! find "$runtime_collects_cache" -path '*/compiled/*.zo' -type f -print -quit 2>/dev/null | grep -q .; then
    die "runtime-keyed staged system compiled cache is empty: $runtime_collects_cache"
  fi
  if ! find "$runtime_pkgs_cache" -path '*/compiled/*.zo' -type f -print -quit 2>/dev/null | grep -q .; then
    die "runtime-keyed staged package compiled cache is empty: $runtime_pkgs_cache"
  fi
}

write_staged_config() {
  local config_file="$1"
  local stage_root="$2"
  local prefix="$3"
  local runtime_cache_root="$4"
  local staged_cache_root="$5"
  local racket_bin="$6"
  local collects_dir="$7"
  local config_dir="$8"
  "$racket_bin" -X "$collects_dir" -G "$config_dir" -e '
(let ()
  (define args (current-command-line-arguments))
  (define config-file (vector-ref args 0))
  (define stage-root (vector-ref args 1))
  (define prefix (vector-ref args 2))
  (define runtime-cache-root (vector-ref args 3))
  (define staged-cache-root (vector-ref args 4))
  (define config (call-with-input-file config-file read))
  (unless (hash? config)
    (error (quote write-staged-config) "expected config.rktd to contain a hash" config-file))
  (unless (equal? (hash-ref config (quote compiled-file-system-cache-root) #f)
                  runtime-cache-root)
    (error (quote write-staged-config) "config missing expected runtime cache root" runtime-cache-root))
  (define (staged-path suffix)
    (string-append stage-root prefix suffix))
  (define updates
    (hash (quote compiled-file-system-cache-root) staged-cache-root
          (quote share-dir) (staged-path "/share/racket")
          (quote pkgs-dir) (staged-path "/share/racket/pkgs")
          (quote doc-dir) (staged-path "/share/doc/racket")
          (quote lib-dir) (staged-path "/lib/racket")
          (quote include-dir) (staged-path "/include/racket")
          (quote bin-dir) (staged-path "/bin")
          (quote apps-dir) (staged-path "/share/applications")
          (quote man-dir) (staged-path "/share/man")))
  (define staged-config
    (for/fold ([config config]) ([(key value) (in-hash updates)])
      (if (hash-has-key? config key)
          (hash-set config key value)
          config)))
  (call-with-output-file config-file
    #:exists (quote truncate/replace)
    (lambda (out)
      (write staged-config out)
      (newline out))))' -- "$config_file" "$stage_root" "$prefix" "$runtime_cache_root" "$staged_cache_root"
}

move_staged_cache_tree() {
  local cache_root="$1"
  local from_source="$2"
  local to_source="$3"
  local from="$cache_root/${from_source#/}"
  local to="$cache_root/${to_source#/}"
  [ -e "$from" ] || return 0
  [ "$from" = "$to" ] && return 0
  mkdir -p "$(dirname "$to")"
  if [ -e "$to" ]; then
    cp -a "$from"/. "$to"/
    rm -rf "$from"
  else
    mv "$from" "$to"
  fi
}

normalize_staged_system_cache() {
  local stage_root="$1"
  local prefix="$2"
  local cache_root="$stage_root/var/cache/racket/compiled"
  move_staged_cache_tree "$cache_root" "$stage_root$prefix/share/racket/collects" "$prefix/share/racket/collects"
  move_staged_cache_tree "$cache_root" "$stage_root$prefix/share/racket/pkgs" "$prefix/share/racket/pkgs"
  rm -f "$stage_root/var/cache/racket/racket-compiled-cache.log"
  find "$cache_root" -type d -empty -delete 2>/dev/null || true
}

build_staged_system_cache() {
  local stage_root="$1"
  local prefix="$2"
  local runtime_cache_root="/var/cache/racket/compiled"
  local staged_cache_root="$stage_root$runtime_cache_root"
  local config_dir config_file collects_dir racket_bin backup
  config_dir=$(find_staged_config_dir "$stage_root" "$prefix")
  config_file="$config_dir/config.rktd"
  collects_dir=$(find_staged_collects_dir "$stage_root" "$prefix")
  racket_bin=$(find_staged_racket "$stage_root" "$prefix")
  backup="$config_file.package-racket-cache-backup"
  cp "$config_file" "$backup"
  write_staged_config "$config_file" "$stage_root" "$prefix" "$runtime_cache_root" "$staged_cache_root" "$racket_bin" "$collects_dir" "$config_dir"
  mkdir -p "$staged_cache_root"
  if ! "$racket_bin" -X "$collects_dir" -G "$config_dir" -N raco -l- raco setup --system --no-user --reset-cache -D --no-pkg-deps; then
    cp "$backup" "$config_file"
    rm -f "$backup"
    return 1
  fi
  cp "$backup" "$config_file"
  rm -f "$backup"
  normalize_staged_system_cache "$stage_root" "$prefix"
  require_staged_system_cache "$stage_root" "$prefix"
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
