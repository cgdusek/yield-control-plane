#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker compose up -d --build postgres localstack

echo "Waiting for LocalStack..."
for _ in $(seq 1 60); do
  if curl -fsS "${LOCALSTACK_ENDPOINT:-http://localhost:4566}/_localstack/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

./scripts/localstack-init.sh
docker compose up -d --build
docker compose ps
