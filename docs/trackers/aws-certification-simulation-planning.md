# AWS Certification Simulation Planning

Status: in-progress
Branch: `main`
Base: `origin/main`

## Objective

Implement a cost-bounded AWS sandbox simulation and internal evidence pack for the yield control plane while preserving the local-only no-real-AWS boundary.

## Source Prompt Digest

The requested work adds ECS/Fargate/Fargate Spot, RDS Postgres, SNS/SQS, DLQs, Secrets Manager, KMS, CloudWatch, budget guardrails, FIS stop-task experiments, k6 workload simulation, Rust/sqlx certification probes, standards mapping, and documented evidence collection.

## Authority And Non-Goals

This is internal engineering certification evidence only. It does not claim legal, investment, accounting, tax, regulatory, SOC, ISO, production deployment, production transfer-agent, or customer-data readiness.

## Boundary Rules

- Local/dev mode must still reject real AWS endpoints.
- AWS commands require `AWS_CERTIFICATION_ENABLED=1`.
- Root identity is rejected for deploy and test loops.
- `us-west-2`, `$50`, and teardown TTL are fixed guardrails.
- All generated evidence is written under ignored `artifacts/aws-certification/`.

## Phase Map

| Phase | Scope | Status |
| --- | --- | --- |
| C1 | Runtime config split for local/dev versus cert AWS SDK behavior | complete |
| C2 | Rust certifier probe crate | complete |
| C3 | OpenTofu AWS simulation stack | complete |
| C4 | k6 workload and opt-in AWS command scripts | complete |
| C5 | Docs, coverage map, Makefile, and validation gate | complete |
| C6 | Local validation and tracker closure | complete |
| C7 | Root bootstrap, temporary-role handoff, live AWS West Spot execution, evidence collection, and teardown | in-progress |
| C8 | Post-campaign hygiene review, generated map refresh, and final closure | in-progress |

## Dependency And Artifact Policy

OpenTofu and k6 are required only for opt-in AWS campaign execution. The local `make validate-aws-certification` gate validates scripts, maps, docs, and HCL structure without making AWS calls.

## Validation Strategy

Run `make validate-aws-certification`, targeted Rust tests for config/messaging/worker/certifier, docs validation, formatting, clippy, and full `make validate`. AWS execution remains opt-in and fail-closed. Smells found during live AWS execution must be converted into validator checks before retry, including Docker context hygiene, service-linked role reconciliation, and Fargate-supported ECS service configuration.

## Handoff Criteria

The workstream is handoff-ready only after the live AWS campaign either passes all evidence gates and tears down, or records a bounded blocker with all partial resources and bootstrap IAM material removed.
