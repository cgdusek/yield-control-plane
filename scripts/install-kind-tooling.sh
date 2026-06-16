#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  cat <<'MSG'
Homebrew is not installed. Install kind and helm manually:
  https://kind.sigs.k8s.io/docs/user/quick-start/#installation
  https://helm.sh/docs/intro/install/
MSG
  exit 0
fi

brew install kind helm
echo "Installed kind and helm through Homebrew."
