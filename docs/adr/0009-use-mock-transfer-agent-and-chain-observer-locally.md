# ADR-0009: Use Local Mock Transfer Agent and Chain Watcher

## Status
Accepted

## Context
The local system must demonstrate transfer-agent confirmation and optional chain observation without real external integrations.

## Decision
Use a local mock transfer-agent service with deterministic idempotency and a local chain-watcher worker that records simulated observations.

## Options Considered
- Omit external confirmations
- Mock service and worker simulation
- Real transfer-agent or chain endpoints

## Rationale
The mock preserves workflow shape and retry/idempotency behavior while avoiding real financial or blockchain operations.

## Consequences
Production semantics are simulated and must not be described as real settlement.

## Validation
Validated by worker tests, mock service tests, smoke scripts, UI copy, and production-readiness documentation.
