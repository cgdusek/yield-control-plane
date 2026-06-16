#!/usr/bin/env bash
set -euo pipefail

action="${1:-smoke}"
cluster="${KIND_CLUSTER_NAME:-yield-control-plane}"

case "$action" in
  up)
    if ! command -v kind >/dev/null 2>&1; then
      echo "kind is missing. Run ./scripts/install-kind-tooling.sh first." >&2
      exit 1
    fi
    kind get clusters | grep -qx "$cluster" || kind create cluster --name "$cluster" --config infra/k8s/kind/cluster.yaml
    docker compose build api outbox-publisher mock-transfer-agent react-console
    for image in yield-control-plane-api:local yield-control-plane-worker:local yield-control-plane-mock-transfer-agent:local yield-control-plane-react-console:local; do
      kind load docker-image "$image" --name "$cluster"
    done
    kubectl apply -k infra/k8s/overlays/local
    kubectl -n yield-control-plane rollout status deploy/localstack --timeout=180s
    kubectl -n yield-control-plane wait --for=condition=complete job/localstack-init --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/api --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/mock-transfer-agent --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/outbox-publisher --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/transfer-agent-worker --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/reconciliation-worker --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/notification-worker --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/chain-watcher --timeout=180s
    kubectl -n yield-control-plane rollout status deploy/react-console --timeout=180s
    ;;
  smoke)
    local_port="${K8S_API_LOCAL_PORT:-18080}"
    kubectl -n yield-control-plane port-forward svc/api "${local_port}:8080" >/tmp/ycp-api-port-forward.log 2>&1 &
    pf_pid=$!
    trap 'kill $pf_pid >/dev/null 2>&1 || true' EXIT
    for _ in $(seq 1 30); do
      if curl -fsS "http://localhost:${local_port}/health" >/dev/null 2>&1; then
        API_BASE_URL="http://localhost:${local_port}" ./scripts/smoke-create-sweep.sh
        exit 0
      fi
      sleep 1
    done
    cat /tmp/ycp-api-port-forward.log >&2 || true
    echo "Kubernetes API port-forward did not become ready on localhost:${local_port}" >&2
    exit 1
    ;;
  down)
    if command -v kind >/dev/null 2>&1 && kind get clusters | grep -qx "$cluster"; then
      kind delete cluster --name "$cluster"
    fi
    ;;
  *)
    echo "usage: $0 up|smoke|down" >&2
    exit 2
    ;;
esac
