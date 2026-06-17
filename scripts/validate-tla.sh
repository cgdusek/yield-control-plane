#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TLA_TOOLS_VERSION="${TLA_TOOLS_VERSION:-v1.7.4}"
TLAPS_RELEASE="${TLAPS_RELEASE:-202210041448}"
TLA_TOOLS_JAR="${TLA_TOOLS_JAR:-$ROOT_DIR/tools/tla2tools.jar}"
TLAPS_DIR="${TLAPS_DIR:-$ROOT_DIR/tools/tlaps}"

mkdir -p "$ROOT_DIR/tools"
rm -rf "$ROOT_DIR/.tlacache"

if [[ ! -f "$TLA_TOOLS_JAR" ]]; then
  curl -fL --retry 3 \
    -o "$TLA_TOOLS_JAR" \
    "https://github.com/tlaplus/tlaplus/releases/download/$TLA_TOOLS_VERSION/tla2tools.jar"
fi

if [[ -x "$TLAPS_DIR/bin/tlapm" ]]; then
  TLAPM_BIN="$TLAPS_DIR/bin/tlapm"
elif command -v tlapm >/dev/null 2>&1; then
  TLAPM_BIN="$(command -v tlapm)"
else
  case "$(uname -s)-$(uname -m)" in
    Darwin-*)
      TLAPS_ASSET="tlaps-1.5.0-i386-darwin-inst.bin"
      ;;
    Linux-x86_64)
      TLAPS_ASSET="tlaps-1.5.0-x86_64-linux-gnu-inst.bin"
      ;;
    *)
      echo "No supported TLAPS bootstrap asset for $(uname -s)-$(uname -m)." >&2
      echo "Install tlapm manually or set TLAPS_DIR to a local TLAPS installation." >&2
      exit 1
      ;;
  esac
  INSTALLER="$(mktemp -t tlaps-inst.XXXXXX)"
  curl -fL --retry 3 \
    -o "$INSTALLER" \
    "https://github.com/tlaplus/tlapm/releases/download/$TLAPS_RELEASE/$TLAPS_ASSET"
  chmod +x "$INSTALLER"
  rm -rf "$TLAPS_DIR"
  "$INSTALLER" -d "$TLAPS_DIR"
  rm -f "$INSTALLER"
  TLAPM_BIN="$TLAPS_DIR/bin/tlapm"
fi

TLAPS_LIB="$("$TLAPM_BIN" --where)"
TLC_METADIR="$(mktemp -d -t ycp-tlc.XXXXXX)"
trap 'rm -rf "$TLC_METADIR" "$ROOT_DIR/.tlacache"' EXIT

java -cp "$TLA_TOOLS_JAR:spec/tla:$TLAPS_LIB" \
  tla2sany.SANY \
  spec/tla/YieldLifecycle.tla \
  spec/tla/YieldLiveness.tla \
  spec/tla/YieldCertificationCapacity.tla \
  spec/tla/YieldCertificationCapacityProofs.tla \
  spec/tla/YieldProofs.tla \
  spec/tla/no_double_sweep.tla

PATH="$(dirname "$TLAPM_BIN"):$TLAPS_LIB/bin:$PATH" \
  "$TLAPM_BIN" -I spec/tla spec/tla/YieldProofs.tla

PATH="$(dirname "$TLAPM_BIN"):$TLAPS_LIB/bin:$PATH" \
  "$TLAPM_BIN" -I spec/tla spec/tla/no_double_sweep.tla

PATH="$(dirname "$TLAPM_BIN"):$TLAPS_LIB/bin:$PATH" \
  "$TLAPM_BIN" -I spec/tla spec/tla/YieldCertificationCapacityProofs.tla

run_tlc() {
  local module="$1"
  local config="$2"
  local name="$3"
  local metadir="$TLC_METADIR/$name"
  mkdir -p "$metadir"
  java -cp "$TLA_TOOLS_JAR:spec/tla" \
    tlc2.TLC \
    -metadir "$metadir" \
    -config "$config" \
    "$module"
}

run_tlc spec/tla/YieldLifecycle.tla spec/tla/YieldControlPlane.cfg safety
run_tlc spec/tla/YieldLiveness.tla spec/tla/YieldLiveness.cfg lifecycle-liveness
run_tlc spec/tla/YieldLiveness.tla spec/tla/YieldExceptionLiveness.cfg exception-liveness
run_tlc spec/tla/YieldLiveness.tla spec/tla/YieldMessagingLiveness.cfg messaging-liveness
run_tlc spec/tla/YieldCertificationCapacity.tla spec/tla/YieldCertificationCapacity.cfg certification-capacity

echo "TLA validation passed."
