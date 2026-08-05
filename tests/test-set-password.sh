#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

app_root="$test_root/AlistFN"
mkdir -p "$app_root/target/bin" "$app_root/cmd" "$app_root/var" "$app_root/etc"
cp "$repo_root/packaging/cmd/set_password" "$app_root/cmd/set_password"
cp "$repo_root/packaging/cmd/main" "$app_root/cmd/main"
chmod 0755 "$app_root/cmd/set_password"

cat > "$app_root/target/bin/alist" <<'EOF'
#!/usr/bin/env bash
set -eu
case "${*: -1}" in
  server)
    sleep 30
    ;;
  *)
    printf '%s\n' "$@" > "$TEST_ARGS_FILE"
    ;;
esac
EOF
chmod 0755 "$app_root/target/bin/alist"
chmod 0755 "$app_root/cmd/main"

password='A safe $password! 123'
args_file="$test_root/args"
TRIM_APPDEST="$app_root/target" \
TRIM_PKGETC="$app_root/etc" \
TRIM_PKGVAR="$app_root/var" \
TEST_ARGS_FILE="$args_file" \
wizard_alist_password="$password" \
wizard_alist_password_confirm="$password" \
  "$app_root/cmd/set_password"

if [[ "$(cat "$app_root/var/.pending-admin-password")" != "$password" ]]; then
  echo "Pending administrator password does not match." >&2
  exit 1
fi

TRIM_APPDEST="$app_root/target" \
TRIM_PKGETC="$app_root/etc" \
TRIM_PKGVAR="$app_root/var" \
TEST_ARGS_FILE="$args_file" \
  "$app_root/cmd/main" start

expected_args="$(printf '%s\n' --data "$app_root/var" admin set "$password")"
actual_args="$(cat "$args_file")"
if [[ "$actual_args" != "$expected_args" ]]; then
  echo "Password command arguments were not passed safely." >&2
  exit 1
fi

if [[ "$(cat "$app_root/etc/admin-password")" != "$password" ]]; then
  echo "Stored administrator password does not match." >&2
  exit 1
fi

if [[ -e "$app_root/var/.pending-admin-password" ]]; then
  echo "Pending password should be removed after it is applied." >&2
  exit 1
fi

TRIM_APPDEST="$app_root/target" \
TRIM_PKGETC="$app_root/etc" \
TRIM_PKGVAR="$app_root/var" \
  "$app_root/cmd/main" stop

if TRIM_APPDEST="$app_root/target" \
  TRIM_PKGETC="$app_root/etc" \
  TRIM_PKGVAR="$app_root/var" \
  TEST_ARGS_FILE="$args_file" \
  wizard_alist_password='password-one' \
  wizard_alist_password_confirm='password-two' \
    "$app_root/cmd/set_password" >/dev/null 2>&1; then
  echo "Mismatched passwords should be rejected." >&2
  exit 1
fi

echo "Password configuration tests passed."
