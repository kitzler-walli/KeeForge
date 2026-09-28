#!/bin/bash
set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
LOCAL_CONFIG_PATH="${REPO_ROOT}/BuildConfig.local.xcconfig"
METADATA_CONFIG_PATH="${REPO_ROOT}/BuildMetadata.xcconfig"

write_metadata() {
  local hash
  hash=$(/usr/bin/git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo dev)
  printf "GIT_COMMIT_HASH = %s\n" "${hash}" > "${METADATA_CONFIG_PATH}"
}

bootstrap_local_config_from_env() {
  if [[ "${BOOTSTRAP_LOCAL_CONFIG_FROM_ENV:-0}" != "1" || -f "${LOCAL_CONFIG_PATH}" ]]; then
    return
  fi

  {
    printf "// Generated from environment variables.\n"
    if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
      printf "DEVELOPMENT_TEAM = %s\n" "${DEVELOPMENT_TEAM}"
    fi
  } > "${LOCAL_CONFIG_PATH}"
}

write_metadata
bootstrap_local_config_from_env

if [[ ! -f "${LOCAL_CONFIG_PATH}" ]]; then
  echo "error: Missing BuildConfig.local.xcconfig. Copy BuildConfig.local.example.xcconfig to BuildConfig.local.xcconfig." >&2
  exit 1
fi
