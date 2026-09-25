#!/usr/bin/env bash
# Stops and removes the e2e Nextcloud, including its data.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker compose -f "${HERE}/compose.yml" down -v
