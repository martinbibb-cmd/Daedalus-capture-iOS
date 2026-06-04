#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required. Install with: brew install xcodegen" >&2
  exit 1
fi

cd "${REPO_ROOT}"
xcodegen generate

cd "${REPO_ROOT}/DaedalusContracts"
swift test

echo "Bootstrap complete. Open ${REPO_ROOT}/DaedalusScan.xcodeproj and run DaedalusScanApp on a physical iPhone."
