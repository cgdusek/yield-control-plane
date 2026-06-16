# Kubernetes Kind

## Install Tools

```bash
./scripts/install-kind-tooling.sh
```

## Validate Manifests

```bash
make validate-k8s
```

This renders `infra/k8s/overlays/local` and `infra/k8s/overlays/aws-shaped`, then checks required resources and local-only endpoint invariants.

## Start

```bash
make k8s-up
```

The script creates the `yield-control-plane` kind cluster if needed, builds local images, loads them into kind, applies manifests, waits for the LocalStack initialization Job, and waits for all deployment rollouts.

## Smoke

```bash
make k8s-smoke
```

The smoke path port-forwards the API on local port `18080` by default and creates a sweep order through the Kubernetes runtime.

## Stop

```bash
make k8s-down
```

