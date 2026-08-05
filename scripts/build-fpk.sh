#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: build-fpk.sh <alist-tag-or-version> <x86|arm> [output-directory]

Environment:
  FN_PACK_BIN     fnpack executable (default: fnpack)
  ALIST_ARCHIVE   optional pre-downloaded upstream .tar.gz
  ALIST_SHA256    expected SHA-256; required unless ALLOW_UNVERIFIED=1
  REPOSITORY      owner/repository used in package metadata
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 2
fi

upstream_tag="$1"
target="$2"
output_dir="${3:-dist}"
fnpack_bin="${FN_PACK_BIN:-fnpack}"
repository="${REPOSITORY:-local/Alist-FN}"

[[ "$upstream_tag" == v* ]] || upstream_tag="v${upstream_tag}"
version="${upstream_tag#v}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid AList version: $version" >&2
  exit 2
fi

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Invalid repository identifier: $repository" >&2
  exit 2
fi

case "$target" in
  x86)
    platform="x86"
    upstream_arch="amd64"
    ;;
  arm)
    platform="arm"
    upstream_arch="arm64"
    ;;
  *)
    echo "Unsupported fnOS architecture: $target" >&2
    usage >&2
    exit 2
    ;;
esac

asset="alist-linux-musl-${upstream_arch}.tar.gz"
asset_url="https://github.com/AlistGo/alist/releases/download/${upstream_tag}/${asset}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

project_dir="${work_dir}/AlistFN"
archive="${work_dir}/${asset}"
extract_dir="${work_dir}/extract"
mkdir -p "$project_dir" "$extract_dir" "$output_dir"
cp -R "${repo_root}/packaging/." "$project_dir/"

if [[ -n "${ALIST_ARCHIVE:-}" ]]; then
  cp "$ALIST_ARCHIVE" "$archive"
else
  curl --fail --location --retry 3 --retry-all-errors \
    --output "$archive" "$asset_url"
fi

if [[ -n "${ALIST_SHA256:-}" ]]; then
  actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$ALIST_SHA256" ]]; then
    echo "SHA-256 mismatch for $asset" >&2
    echo "expected: $ALIST_SHA256" >&2
    echo "actual:   $actual_sha256" >&2
    exit 1
  fi
elif [[ "${ALLOW_UNVERIFIED:-0}" != "1" ]]; then
  echo "ALIST_SHA256 is required (set ALLOW_UNVERIFIED=1 only for local testing)." >&2
  exit 1
fi

tar -xzf "$archive" -C "$extract_dir"
if [[ ! -f "${extract_dir}/alist" ]]; then
  echo "Upstream archive does not contain the expected 'alist' executable." >&2
  exit 1
fi

install -m 0755 "${extract_dir}/alist" "${project_dir}/app/bin/alist"
rm -f "${project_dir}/app/bin/.gitkeep"

mkdir -p "${project_dir}/licenses"
cp "${repo_root}/packaging/licenses/AList-AGPL-3.0.txt" \
  "${project_dir}/licenses/AList-AGPL-3.0.txt"
cp "${repo_root}/THIRD_PARTY_NOTICES.md" "${project_dir}/licenses/THIRD_PARTY_NOTICES.md"

sed \
  -e "s|@VERSION@|${version}|g" \
  -e "s|@UPSTREAM_TAG@|${upstream_tag}|g" \
  -e "s|@PLATFORM@|${platform}|g" \
  -e "s|@REPOSITORY@|${repository}|g" \
  "${project_dir}/manifest.in" > "${project_dir}/manifest"
rm "${project_dir}/manifest.in"

chmod 0755 "${project_dir}/cmd/"*

before_count="$(find "$project_dir" -maxdepth 1 -type f -name '*.fpk' | wc -l | tr -d ' ')"
if [[ "$before_count" != "0" ]]; then
  echo "Packaging template unexpectedly contains an .fpk file." >&2
  exit 1
fi

(
  cd "$project_dir"
  "$fnpack_bin" build
)

package_count="$(find "$project_dir" -maxdepth 2 -type f -name '*.fpk' | wc -l | tr -d ' ')"
if [[ "$package_count" != "1" ]]; then
  echo "Expected fnpack to produce exactly one .fpk, found ${package_count}." >&2
  exit 1
fi
package="$(find "$project_dir" -maxdepth 2 -type f -name '*.fpk' -print -quit)"

destination="${output_dir}/AlistFN-${version}-${platform}.fpk"
cp "$package" "$destination"
shasum -a 256 "$destination"
echo "Created $destination"
