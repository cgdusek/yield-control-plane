#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is required for Rust source proof validation." >&2
  exit 1
fi

if ! cargo kani --version >/dev/null 2>&1; then
  echo "Kani is required for Rust source proof validation. Install with: cargo install --locked kani-verifier && cargo kani setup" >&2
  exit 1
fi

cargo kani -p institutional-yield-domain
