---
id: c4-evidence-pack
title: C4 Model Evidence Pack
source_of_truth:
  - model-elements.yaml
  - relationships.yaml
  - deployment-map.yaml
  - evidence-map.yaml
last_reviewed: 2026-06-18
---

# C4 Model Evidence Pack

## Purpose

This pack documents the Yield Control Plane architecture with C4-style system context, container, and component views. Mermaid diagrams are the visual view. YAML files are the structured source of truth.

## Scope

The scope is the existing React console, Rust API, Rust workers, Rust certifier, mock transfer-agent simulator, Postgres, LocalStack SNS/SQS, non-production AWS sandbox simulation, GitHub CI, validation scripts, and evidence artifact paths.

## Non-Claims

This pack does not create SOC attestation, AWS assurance, regulatory approval, legal advice, investment advice, tax advice, accounting advice, transfer-agent authorization, customer-data authorization, production authorization, or production readiness.

## C4 Legend

| Type | ID Pattern | Mermaid Convention |
| --- | --- | --- |
| Person or external actor | `PER-###` | Node label includes `PER-### Person: Name` |
| Software system | `SYS-###` | Node label includes `SYS-### Software System: Name` |
| Container | `CON-###` | Node label includes `CON-### Container: Name` |
| Component | `CMP-###` | Node label includes `CMP-### Component: Name` |
| Module or source evidence | `MOD-###` | Node label includes `MOD-### Module: Name` |
| Boundary | `BND-###` | Mermaid `subgraph` labeled with the boundary ID |
| Relationship | `REL-###` | Arrow label includes ID and short relationship name |

## Source Catalogs

- [Model elements](model-elements.yaml) define people, systems, containers, components, modules, responsibilities, technology, deployment contexts, and source files.
- [Relationships](relationships.yaml) define architecture interactions, protocols, sync or async mode, related DFD flows, diagrams, and source files.
- [Deployment map](deployment-map.yaml) maps elements to local, Kubernetes, AWS sandbox, CI, and evidence contexts.
- [Evidence map](evidence-map.yaml) links C4 elements and relationships to DFD controls, validation commands, and source evidence.

## Diagram Index

- [C4 00 System Context](c4-00-system-context.md)
- [C4 01 Local Runtime Containers](c4-01-local-runtime-containers.md)
- [C4 02 AWS Sandbox Containers](c4-02-aws-sandbox-containers.md)
- [C4 03 API Components](c4-03-api-components.md)
- [C4 04 Worker Components](c4-04-worker-components.md)
- [C4 05 Persistence and Domain Components](c4-05-persistence-domain-components.md)
- [C4 06 CI and Evidence Operations](c4-06-ci-evidence-operations.md)

## DFD Cross-Reference

The C4 model does not replace the [DFD evidence pack](../../security/dfd/README.md). C4 relationships reference `DF-###` entries where an architecture interaction carries modeled data. DFD controls and trust boundaries remain the control taxonomy source.

## How To Validate The C4 Pack

Run the dedicated C4 gate:

```bash
make validate-c4
```

The validator checks required files, YAML syntax, diagram-to-catalog `REL-###` references, C4 element references, DFD flow and control references, source-file references, unfinished markers, relationship coverage, and unsupported external-assurance wording.

## Readiness Support

This pack supports architecture readiness review by making ownership, deployment shape, source evidence, control references, and runtime relationships explicit and machine-checkable. It is evidence for internal review only and does not grant external approval or production authorization.
