# ADR-0008: Provide kind Kubernetes Bootstrap

## Status
Accepted

## Context
The source specification requires Kubernetes manifests without depending on real AWS.

## Decision
Provide base manifests, a local kustomize overlay, a kind cluster config, and scripts that load local images into kind.

## Options Considered
- Compose only
- kind local cluster
- Managed cloud cluster

## Rationale
kind validates Kubernetes packaging and probes while keeping all resources local.

## Consequences
The Kubernetes gate depends on optional kind tooling and Docker capacity.

## Validation
Validated by `kubectl apply -k`/dry-run where available, `scripts/smoke-k8s.sh`, and CI manifest checks.
