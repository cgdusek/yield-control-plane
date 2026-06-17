#!/usr/bin/env bash
set -euo pipefail

required=(rustc cargo node npm pnpm docker make jq curl aws kubectl java)
optional=(awslocal kind helm just tlapm tofu opentofu k6)

missing=()
for tool in "${required[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  missing+=("docker compose")
fi

echo "Required tools:"
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    case "$tool" in
      kubectl) printf "  %-18s %s\n" "$tool" "$(kubectl version --client=true 2>/dev/null | head -n 1)" ;;
      java) printf "  %-18s %s\n" "$tool" "$(java -version 2>&1 | head -n 1)" ;;
      *) printf "  %-18s %s\n" "$tool" "$($tool --version 2>&1 | head -n 1)" ;;
    esac
  else
    printf "  %-18s missing\n" "$tool"
  fi
done
printf "  %-18s %s\n" "docker compose" "$(docker compose version 2>&1 | head -n 1 || true)"

echo "Optional tools:"
for tool in "${optional[@]}"; do
  if [[ "$tool" == "tlapm" && -x "./tools/tlaps/bin/tlapm" ]]; then
    printf "  %-18s %s\n" "$tool" "$(./tools/tlaps/bin/tlapm --version 2>&1 | head -n 1)"
  elif command -v "$tool" >/dev/null 2>&1; then
    case "$tool" in
      helm) printf "  %-18s %s\n" "$tool" "$(helm version 2>&1 | head -n 1)" ;;
      kind|just|tofu|opentofu|k6) printf "  %-18s %s\n" "$tool" "$($tool --version 2>&1 | head -n 1)" ;;
      *) printf "  %-18s installed\n" "$tool" ;;
    esac
  else
    printf "  %-18s missing\n" "$tool"
  fi
done

if ((${#missing[@]} > 0)); then
  echo "Missing required tools: ${missing[*]}" >&2
  exit 1
fi

echo "Tool check passed."
