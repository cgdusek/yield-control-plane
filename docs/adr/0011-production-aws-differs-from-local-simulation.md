# ADR-0011: Document How Production AWS Differs from Local Simulation

## Status
Accepted

## Context
The local stack is production-shaped but cannot claim real production readiness or cloud security posture.

## Decision
Document the production mapping separately: EKS, IAM/IRSA or Pod Identity, real SNS/SQS, Secrets Manager, KMS, external transfer-agent connectivity, observability, backup, and disaster recovery.

## Options Considered
- Claim Compose approximates production fully
- Document production deltas explicitly
- Implement real AWS deployment

## Rationale
Explicit deltas prevent overclaiming while preserving deployable architecture intent.

## Consequences
Production deployment remains out of scope for the local demo.

## Validation
Validated by `docs/production-readiness.md`, AWS-shaped Kubernetes overlays, security docs, and ADR references.
