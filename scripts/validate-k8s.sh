#!/usr/bin/env bash
set -euo pipefail

for overlay in local aws-shaped; do
  rendered="$(mktemp)"
  kubectl kustomize "infra/k8s/overlays/${overlay}" > "$rendered"
  python3 - "$overlay" "$rendered" <<'PY'
import sys
from pathlib import Path

import yaml

overlay = sys.argv[1]
path = Path(sys.argv[2])
docs = [doc for doc in yaml.safe_load_all(path.read_text()) if doc]

def fail(message: str) -> None:
    raise SystemExit(f"{overlay}: {message}")

ids = {(doc.get("kind"), doc.get("metadata", {}).get("name")) for doc in docs}
required = {
    ("Namespace", "yield-control-plane"),
    ("Secret", "local-dev-secrets"),
    ("ConfigMap", "app-config"),
    ("StatefulSet", "postgres"),
    ("Service", "postgres"),
    ("Deployment", "localstack"),
    ("Service", "localstack"),
    ("Job", "localstack-init"),
    ("Deployment", "api"),
    ("Service", "api"),
    ("Deployment", "mock-transfer-agent"),
    ("Service", "mock-transfer-agent"),
    ("Deployment", "react-console"),
    ("Service", "react-console"),
    ("Deployment", "outbox-publisher"),
    ("Deployment", "transfer-agent-worker"),
    ("Deployment", "reconciliation-worker"),
    ("Deployment", "notification-worker"),
    ("Deployment", "chain-watcher"),
}
missing = sorted(required - ids)
if missing:
    fail(f"missing resources: {missing}")

by_id = {(doc.get("kind"), doc.get("metadata", {}).get("name")): doc for doc in docs}
config = by_id[("ConfigMap", "app-config")]["data"]
if "localstack" not in config["LOCALSTACK_ENDPOINT"] or "amazonaws.com" in config["LOCALSTACK_ENDPOINT"]:
    fail("LOCALSTACK_ENDPOINT must stay local-only")
if config["VITE_PROXY_TARGET"] != "http://api:8080":
    fail("React console proxy must target the in-cluster API service")

secret = by_id[("Secret", "local-dev-secrets")]["stringData"]
if "postgres:5432" not in secret["DATABASE_URL"]:
    fail("DATABASE_URL must target the in-cluster Postgres service")

worker_names = {
    "outbox-publisher",
    "transfer-agent-worker",
    "reconciliation-worker",
    "notification-worker",
    "chain-watcher",
}
for name in worker_names | {"api", "mock-transfer-agent"}:
    deploy = by_id[("Deployment", name)]
    spec = deploy["spec"]["template"]["spec"]
    containers = spec.get("containers", [])
    if not containers:
        fail(f"{name} has no containers")
    for container in containers:
        image = container.get("image", "")
        if not image or image.endswith(":latest"):
            fail(f"{name} has missing or latest image tag")
    if name in worker_names:
        init_names = {container["name"] for container in spec.get("initContainers", [])}
        if "wait-for-postgres" not in init_names:
            fail(f"{name} must wait for Postgres")
        if name == "outbox-publisher":
            if "wait-for-topic" not in init_names:
                fail("outbox-publisher must wait for SNS topic")
        elif "wait-for-queue" not in init_names:
            fail(f"{name} must wait for its SQS queue")

job = by_id[("Job", "localstack-init")]
job_command = "\n".join(job["spec"]["template"]["spec"]["containers"][0]["command"])
for expected in ("create-topic", "create-queue", "subscribe", "set-queue-attributes"):
    if expected not in job_command:
        fail(f"localstack-init job does not run {expected}")

for doc in docs:
    kind = doc.get("kind")
    name = doc.get("metadata", {}).get("name")
    namespace = doc.get("metadata", {}).get("namespace")
    if kind != "Namespace" and namespace not in (None, "yield-control-plane"):
        fail(f"{kind}/{name} has unexpected namespace {namespace!r}")

if overlay == "aws-shaped":
    for name in ("api", "outbox-publisher", "transfer-agent-worker", "reconciliation-worker"):
        replicas = by_id[("Deployment", name)]["spec"].get("replicas")
        if replicas != 2:
            fail(f"aws-shaped overlay must set {name} replicas to 2")

print(f"{overlay}: {len(docs)} rendered Kubernetes resources validated")
PY
  rm -f "$rendered"
done

