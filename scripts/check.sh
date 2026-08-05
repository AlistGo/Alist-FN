#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$repo_root"/scripts/*.sh "$repo_root"/packaging/cmd/* "$repo_root"/tests/*.sh; do
  bash -n "$script"
done

jq -e . "$repo_root/packaging/config/privilege" >/dev/null
jq -e . "$repo_root/packaging/config/resource" >/dev/null
jq -e . "$repo_root/packaging/app/ui/config" >/dev/null

required=(
  packaging/manifest.in
  packaging/config/privilege
  packaging/config/resource
  packaging/ICON.PNG
  packaging/ICON_256.PNG
  packaging/app/ui/config
  packaging/app/ui/images/icon_64.png
  packaging/app/ui/images/icon_256.png
  packaging/cmd/main
  packaging/wizard/.gitkeep
)

for path in "${required[@]}"; do
  if [[ ! -e "$repo_root/$path" ]]; then
    echo "Missing required path: $path" >&2
    exit 1
  fi
done

echo "Static checks passed."
