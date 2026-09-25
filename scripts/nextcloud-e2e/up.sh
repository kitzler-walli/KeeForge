#!/usr/bin/env bash
# Starts the e2e Nextcloud and uploads the fixture database to
# /Vaults/nextpass-e2e.kdbx for user e2e-admin. Idempotent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
BASE_URL="http://localhost:8480"
USER="e2e-admin"
PASS="e2e-admin-password"
FIXTURE="${REPO_ROOT}/TestFixtures/test.kdbx"
DAV="${BASE_URL}/remote.php/dav/files/${USER}"

docker compose -f "${HERE}/compose.yml" up -d

echo "Waiting for Nextcloud to finish installing..."
for _ in $(seq 1 120); do
  if curl -fsS "${BASE_URL}/status.php" 2>/dev/null | grep -q '"installed":true'; then
    break
  fi
  sleep 2
done
curl -fsS "${BASE_URL}/status.php" | grep -q '"installed":true' || {
  echo "error: Nextcloud did not come up at ${BASE_URL}" >&2
  exit 1
}

# First-login onboarding would otherwise sit between the login form and the
# Login Flow v2 grant page.
docker compose -f "${HERE}/compose.yml" exec -T -u www-data nextcloud \
  php occ app:disable firstrunwizard >/dev/null 2>&1 || true

curl -fsS -u "${USER}:${PASS}" -X MKCOL "${DAV}/Vaults" -o /dev/null 2>/dev/null || true
curl -fsS -u "${USER}:${PASS}" -T "${FIXTURE}" "${DAV}/Vaults/nextpass-e2e.kdbx"
echo "Uploaded ${FIXTURE##*/} to ${DAV}/Vaults/nextpass-e2e.kdbx"
