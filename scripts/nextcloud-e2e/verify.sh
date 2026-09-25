#!/usr/bin/env bash
# Downloads /Vaults/nextpass-e2e.kdbx from the e2e Nextcloud and checks, with
# KeePassXC as an independent reader, that the UI test's entry was saved with
# the Apple Watch tag and its TOTP secret.
set -euo pipefail

BASE_URL="http://localhost:8480"
USER="e2e-admin"
PASS="e2e-admin-password"
DB_PASSWORD="testpassword123"
ENTRY="Watch E2E"
KEEPASSXC_CLI="${KEEPASSXC_CLI:-keepassxc-cli}"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
curl -fsS -u "${USER}:${PASS}" -o "${tmp}/db.kdbx" \
  "${BASE_URL}/remote.php/dav/files/${USER}/Vaults/nextpass-e2e.kdbx"

show() { printf '%s\n' "${DB_PASSWORD}" | "${KEEPASSXC_CLI}" show -q "$@" "${tmp}/db.kdbx" "${ENTRY}"; }

tags="$(show -a Tags)"
[[ ";${tags};" == *";Apple Watch;"* ]] || { echo "FAIL: '${ENTRY}' tags are '${tags}'" >&2; exit 1; }
[[ "$(show -a UserName)" == "watch-user" ]] || { echo "FAIL: username mismatch" >&2; exit 1; }
[[ "$(show -s -a Password)" == "WatchSecret-42" ]] || { echo "FAIL: password mismatch" >&2; exit 1; }
totp="$(show -t)"
[[ "${totp}" =~ ^[0-9]{6}$ ]] || { echo "FAIL: no TOTP code (${totp})" >&2; exit 1; }
echo "OK: '${ENTRY}' is tagged Apple Watch and yields TOTP ${totp}"
