#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if command -v corepack >/dev/null 2>&1; then
  corepack enable >/dev/null 2>&1 || true
fi

./scripts/check-tools.sh

if ! command -v kind >/dev/null 2>&1 || ! command -v helm >/dev/null 2>&1; then
  echo "Optional Kubernetes demo tools are missing."
  echo "Run ./scripts/install-kind-tooling.sh for Homebrew-based install guidance."
fi

if [[ ! -f .env ]]; then
  echo "No .env file found. Copy .env.example to .env if you want to override defaults."
fi

echo "Bootstrap complete."
