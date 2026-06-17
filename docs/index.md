# Documentation Index

Start here for the local institutional yield control plane.

- [Bootstrap](bootstrap.md)
- [Architecture](architecture.md)
- [Local development](local-development.md)
- [Testing](testing.md)
- [Operations](operations.md)
- [Security](security.md)
- [Formal verification](formal-verification.md)
- [Liveness verification](liveness-verification.md)
- [AWS simulation and internal certification](aws-certification.md)
- [AWS simulation internal certification report - 2026-06-17](certification/aws-simulation-internal-certification-report-2026-06-17.md)
- [Production readiness](production-readiness.md)
- [Runbooks](runbooks/index.md)
- [Traceability](traceability.md)
- [Agentic handoff](agentic/index.md)
- [ADRs](adr/README.md)

Primary specs:

- [OpenAPI](../spec/openapi.yaml)
- [AsyncAPI](../spec/asyncapi.yaml)
- [Sweep order state machine](../spec/domain/sweep_order.machine.yaml)
- [Formal TLA+ proof module](../spec/tla/YieldProofs.tla)
- [Formal TLA+ liveness module](../spec/tla/YieldLiveness.tla)
- [AWS certification capacity model](../spec/tla/YieldCertificationCapacity.tla)
- [AWS certification capacity proofs](../spec/tla/YieldCertificationCapacityProofs.tla)
- [Rust-to-TLA mapping](../spec/refinement/rust_tla_mapping.yaml)
- [Invariant coverage matrix](../spec/refinement/invariant_coverage.yaml)
- [Liveness coverage matrix](../spec/refinement/liveness_coverage.yaml)
- [AWS certification coverage map](../spec/certification/aws_certification_coverage_map.json)
