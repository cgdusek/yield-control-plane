#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


DEFAULT_OUTPUT = Path("spec/refinement/repo_surface_coverage_map.json")
DERIVED_SELF_ARTIFACTS = {str(DEFAULT_OUTPUT)}
SOURCE_PROOF_PATHS = [
    "crates/domain/src/asset.rs",
    "crates/domain/src/sweep.rs",
    "crates/domain/src/abstract_refinement.rs",
    "crates/domain/src/certification.rs",
]
SOURCE_PROOF_OBLIGATIONS = [
    {
        "id": "asset.fidd_only_builtin_forbidden_yield_source",
        "path": "crates/domain/src/asset.rs",
        "harness": "fidd_is_the_only_builtin_asset_forbidden_as_yield_source",
    },
    {
        "id": "asset.builtin_cash_rails_exact",
        "path": "crates/domain/src/asset.rs",
        "harness": "builtin_cash_rails_are_exactly_usd_and_fidd",
    },
    {
        "id": "transition.accepted_transitions_never_stutter",
        "path": "crates/domain/src/sweep.rs",
        "harness": "accepted_transitions_never_stutter_and_preserve_source_command",
    },
    {
        "id": "transition.active_requires_reconciled_source",
        "path": "crates/domain/src/sweep.rs",
        "harness": "active_can_only_be_reached_by_activate_from_reconciled",
    },
    {
        "id": "transition.cash_credit_requires_redemption_confirmation",
        "path": "crates/domain/src/sweep.rs",
        "harness": "cash_credited_can_only_be_reached_after_redemption_confirmation",
    },
    {
        "id": "transition.position_booking_requires_transfer_agent_confirmation",
        "path": "crates/domain/src/sweep.rs",
        "harness": "position_booked_requires_transfer_agent_confirmation",
    },
    {
        "id": "transition.cancel_pre_submission_only",
        "path": "crates/domain/src/sweep.rs",
        "harness": "cancellation_is_limited_to_pre_submission_states",
    },
    {
        "id": "transition.exception_open_excludes_terminal_statuses",
        "path": "crates/domain/src/sweep.rs",
        "harness": "exception_open_excludes_terminal_statuses",
    },
    {
        "id": "mapping.mapped_parts_match_command_action",
        "path": "crates/domain/src/abstract_refinement.rs",
        "harness": "mapped_parts_always_match_command_action",
    },
    {
        "id": "mapping.activate_only_reconciled_to_active",
        "path": "crates/domain/src/abstract_refinement.rs",
        "harness": "mapped_activate_only_from_reconciled_to_active",
    },
    {
        "id": "mapping.book_position_has_transfer_agent_source",
        "path": "crates/domain/src/abstract_refinement.rs",
        "harness": "mapped_book_position_has_transfer_agent_source_status",
    },
    {
        "id": "mapping.credit_cash_only_redemption_confirmed",
        "path": "crates/domain/src/abstract_refinement.rs",
        "harness": "mapped_credit_cash_only_from_redemption_confirmed",
    },
    {
        "id": "mapping.cancel_pre_submission_only",
        "path": "crates/domain/src/abstract_refinement.rs",
        "harness": "mapped_cancel_is_limited_to_pre_submission",
    },
    {
        "id": "mapping.open_exception_excludes_terminal_statuses",
        "path": "crates/domain/src/abstract_refinement.rs",
        "harness": "mapped_open_exception_excludes_terminal_statuses",
    },
    {
        "id": "certification.over_budget_blocks_enforced_campaign",
        "path": "crates/domain/src/certification.rs",
        "harness": "over_budget_blocks_enforced_campaign",
    },
    {
        "id": "certification.cleanup_mode_allows_evidence_collection",
        "path": "crates/domain/src/certification.rs",
        "harness": "cleanup_mode_allows_over_budget_evidence_collection",
    },
    {
        "id": "certification.dirty_queue_blocks_campaign_start",
        "path": "crates/domain/src/certification.rs",
        "harness": "dirty_queue_blocks_campaign_start",
    },
    {
        "id": "certification.dirty_queue_error_precedence_when_budget_allows",
        "path": "crates/domain/src/certification.rs",
        "harness": "dirty_queue_is_reported_when_budget_allows_start",
    },
    {
        "id": "certification.zero_duration_blocks_campaign_start",
        "path": "crates/domain/src/certification.rs",
        "harness": "zero_duration_blocks_campaign_start",
    },
    {
        "id": "certification.admitted_rate_within_capacity",
        "path": "crates/domain/src/certification.rs",
        "harness": "admitted_campaign_rate_is_within_queue_and_db_capacity",
    },
    {
        "id": "certification.arrival_rate_is_positive_ceiling",
        "path": "crates/domain/src/certification.rs",
        "harness": "arrival_rate_is_positive_ceiling_for_bounded_inputs",
    },
    {
        "id": "certification.drain_tick_never_increases_queue",
        "path": "crates/domain/src/certification.rs",
        "harness": "drain_tick_never_increases_queue",
    },
    {
        "id": "certification.positive_capacity_drains_bounded_queue",
        "path": "crates/domain/src/certification.rs",
        "harness": "positive_capacity_eventually_drains_bounded_queue",
    },
]
SOURCE_PROOF_BOUNDARY_REASONS = {
    "rust_persistence_and_sql": "Postgres constraints, triggers, migrations, and SQLx repository behavior are covered by DB-backed tests, runtime constraints, and formal invariant mapping; source-level Rust proof would not prove Postgres execution semantics.",
    "rust_messaging_localstack": "SNS/SQS behavior depends on AWS SDK and LocalStack/network semantics, so the sane proof layer is abstract TLA+/TLC plus worker tests and smoke gates.",
    "rust_api_service": "HTTP extraction, middleware, and OpenAPI conformance are covered by route tests, spec validation, and smoke gates; Kani over the async service stack would add little assurance without a large model rewrite.",
    "rust_workers_and_mocks": "Worker progress depends on async queues, persistence, and external simulator behavior, so it is covered by liveness models, unit tests, DB tests, and smoke/failure-path gates.",
    "shared_rust_infra": "Config and observability code is small and runtime-enforced by tests; no critical pure finite protocol kernel is present.",
}


AXIS_ACTIONS = {
    "source_inventory": "Assign all files in this surface and keep unmapped files at zero.",
    "specification_or_contract": "Add or bind this surface to an OpenAPI, AsyncAPI, state-machine, TLA+, schema, or documented contract.",
    "static_validation": "Add a deterministic local validator for this surface.",
    "unit_or_property_tests": "Add unit, property, route, or component tests for this surface.",
    "database_integration": "Add DB-backed validation for this surface.",
    "runtime_or_smoke": "Add Docker, LocalStack, kind, or smoke evidence for this surface.",
    "runtime_enforcement": "Bind the rule to a domain guard, SQL constraint, middleware, worker policy, or runtime script.",
    "formal_model": "Add or extend the TLA+/TLAPS/TLC model for the safety or liveness semantics on this surface.",
    "formal_projection": "Map implementation traces or commands from this surface into the abstract formal protocol.",
    "source_level_proof": "Add a bounded source-level proof harness for the narrow implementation kernel where theorem-prover effort is justified.",
    "drift_validator": "Add a script that fails when this surface drifts from its source of truth.",
    "ci_gate": "Invoke the surface validator from make validate or GitHub Actions.",
    "documentation": "Document the surface and its validation commands.",
}


@dataclass(frozen=True)
class Surface:
    id: str
    title: str
    patterns: tuple[str, ...]
    exclude: tuple[str, ...] = ()
    required_axes: tuple[str, ...] = ()
    evidence: dict[str, dict[str, list[str]]] = field(default_factory=dict)
    formal_scope: str = "none"
    hardening_frontier: tuple[str, ...] = ()


SURFACES: tuple[Surface, ...] = (
    Surface(
        id="repository_control_plane",
        title="Repository Control Plane",
        patterns=(
            ".dockerignore",
            ".editorconfig",
            ".env.example",
            ".gitignore",
            "AGENTS.md",
            "AGENT_TRACKER.md",
            "Cargo.lock",
            "Cargo.toml",
            "Makefile",
            "README.md",
            "justfile",
            "pnpm-lock.yaml",
            "pnpm-workspace.yaml",
        ),
        required_axes=("source_inventory", "static_validation", "ci_gate", "documentation"),
        evidence={
            "static_validation": {"commands": ["make check-tools", "make validate"], "paths": ["scripts/check-tools.sh"]},
            "ci_gate": {"commands": ["make validate"], "paths": [".github/workflows/ci.yml"]},
            "documentation": {"paths": ["README.md", "AGENTS.md", "AGENT_TRACKER.md"]},
        },
        hardening_frontier=("Add a release artifact manifest if this repo starts publishing deployable versions.",),
    ),
    Surface(
        id="ci_cd",
        title="CI/CD Gates",
        patterns=(".github/**", "scripts/validate-all.sh", "scripts/check-tools.sh", "scripts/bootstrap-local.sh"),
        required_axes=("source_inventory", "static_validation", "runtime_or_smoke", "ci_gate", "documentation"),
        evidence={
            "static_validation": {"commands": ["make validate"], "paths": ["scripts/validate-all.sh"]},
            "runtime_or_smoke": {"commands": ["make smoke", "make smoke-failure-paths"], "paths": [".github/workflows/ci.yml"]},
            "ci_gate": {"paths": [".github/workflows/ci.yml"]},
            "documentation": {"paths": ["docs/testing.md", "docs/bootstrap.md"]},
        },
        hardening_frontier=("Add branch protection or required-check policy evidence if repository administration becomes in scope.",),
    ),
    Surface(
        id="formal_methods",
        title="TLA+, TLAPS, and TLC",
        patterns=("spec/tla/**", "scripts/validate-tla.sh", "docs/formal-verification.md", "docs/liveness-verification.md"),
        required_axes=("source_inventory", "specification_or_contract", "formal_model", "drift_validator", "ci_gate", "documentation"),
        evidence={
            "specification_or_contract": {"paths": ["spec/tla/YieldLifecycle.tla", "spec/tla/YieldLiveness.tla"]},
            "formal_model": {"commands": ["make validate-tla"], "paths": ["spec/tla/YieldProofs.tla", "spec/tla/YieldControlPlane.cfg"]},
            "drift_validator": {"paths": ["scripts/validate-tla.sh"]},
            "ci_gate": {"commands": ["make validate-tla", "make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/formal-verification.md", "docs/liveness-verification.md"]},
        },
        formal_scope="abstract_protocol_safety_and_bounded_liveness",
        hardening_frontier=("Increase TLC model bounds or split larger liveness models when state-space growth permits.",),
    ),
    Surface(
        id="coverage_governance",
        title="Coverage Governance and Drift Maps",
        patterns=(
            "spec/refinement/**",
            "scripts/generate-formal-coverage-map.py",
            "scripts/generate-repo-surface-coverage-map.py",
            "scripts/validate-formal-coverage-map.sh",
            "scripts/validate-repo-surface-coverage-map.sh",
            "scripts/validate-formal-coverage.sh",
            "scripts/validate-liveness-coverage.sh",
            "scripts/validate-refinement.sh",
        ),
        exclude=tuple(DERIVED_SELF_ARTIFACTS),
        required_axes=("source_inventory", "specification_or_contract", "drift_validator", "ci_gate", "documentation"),
        evidence={
            "specification_or_contract": {
                "paths": [
                    "spec/refinement/invariant_coverage.yaml",
                    "spec/refinement/liveness_coverage.yaml",
                    "spec/refinement/rust_tla_mapping.yaml",
                    "spec/refinement/formal_coverage_map.json",
                ]
            },
            "drift_validator": {
                "commands": [
                    "make validate-formal-coverage",
                    "make validate-liveness",
                    "make validate-refinement",
                    "make validate-formal-coverage-map",
                    "make validate-repo-surface-coverage-map",
                ],
                "paths": [
                    "scripts/validate-formal-coverage.sh",
                    "scripts/validate-liveness-coverage.sh",
                    "scripts/validate-refinement.sh",
                    "scripts/validate-formal-coverage-map.sh",
                    "scripts/validate-repo-surface-coverage-map.sh",
                ],
            },
            "ci_gate": {"commands": ["make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/formal-verification.md", "docs/testing.md"]},
        },
        formal_scope="meta_coverage_for_formal_artifacts",
        hardening_frontier=("Add severity weights per invariant if prioritization becomes ambiguous.",),
    ),
    Surface(
        id="api_event_and_domain_specs",
        title="API, Event, and Domain Specifications",
        patterns=("spec/openapi.yaml", "spec/asyncapi.yaml", "spec/domain/**", "spec/schemas/**", "spec/diagrams/**", "spec/source/**", "scripts/validate-specs.sh"),
        required_axes=("source_inventory", "specification_or_contract", "static_validation", "drift_validator", "ci_gate", "documentation"),
        evidence={
            "specification_or_contract": {"paths": ["spec/openapi.yaml", "spec/asyncapi.yaml", "spec/domain/sweep_order.machine.yaml"]},
            "static_validation": {"commands": ["make validate-specs"], "paths": ["scripts/validate-specs.sh"]},
            "drift_validator": {"paths": ["scripts/validate-specs.sh"]},
            "ci_gate": {"commands": ["make validate-specs", "make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/traceability.md", "docs/architecture.md"]},
        },
        hardening_frontier=("Add full JSON Schema validation when the validator dependency is intentionally pinned.",),
    ),
    Surface(
        id="rust_domain_core",
        title="Rust Domain Core",
        patterns=("crates/domain/**", "scripts/validate-source-proofs.sh"),
        required_axes=(
            "source_inventory",
            "specification_or_contract",
            "unit_or_property_tests",
            "formal_projection",
            "source_level_proof",
            "drift_validator",
            "ci_gate",
            "documentation",
        ),
        evidence={
            "specification_or_contract": {"paths": ["spec/domain/sweep_order.machine.yaml", "spec/tla/YieldLifecycle.tla"]},
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["crates/domain/tests"]},
            "formal_projection": {"commands": ["make validate-refinement"], "paths": ["crates/domain/src/abstract_refinement.rs", "spec/refinement/rust_tla_mapping.yaml"]},
            "source_level_proof": {
                "commands": ["make validate-source-proofs"],
                "paths": ["scripts/validate-source-proofs.sh", *SOURCE_PROOF_PATHS],
            },
            "drift_validator": {"paths": ["scripts/validate-refinement.sh", "scripts/validate-formal-coverage.sh"]},
            "ci_gate": {"commands": ["make validate", "make validate-source-proofs"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/formal-verification.md", "docs/traceability.md"]},
        },
        formal_scope="rust_transitions_project_to_abstract_tla_actions_with_targeted_source_proof",
        hardening_frontier=("Targeted Kani proof covers the finite built-in asset classifier, transition, Rust-to-TLA mapping, and AWS certification admission kernels; full line-level proof for services, async workers, SQL, frontend, and infrastructure remains intentionally out of scope.",),
    ),
    Surface(
        id="rust_persistence_and_sql",
        title="Rust Persistence and SQL Enforcement",
        patterns=("crates/persistence/**",),
        required_axes=("source_inventory", "unit_or_property_tests", "database_integration", "runtime_enforcement", "formal_projection", "ci_gate", "documentation"),
        evidence={
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["crates/persistence/tests/repository_tests.rs"]},
            "database_integration": {
                "commands": ["RUN_DATABASE_TESTS=1 DATABASE_URL=postgres://yield:yield@127.0.0.1:15432/yield_control cargo test -p institutional-yield-persistence --all-features"],
                "paths": ["crates/persistence/tests/repository_tests.rs"],
            },
            "runtime_enforcement": {"paths": ["crates/persistence/migrations/20260616150400_initial.sql", "crates/persistence/src/repositories.rs"]},
            "formal_projection": {"paths": ["spec/refinement/invariant_coverage.yaml"]},
            "ci_gate": {"paths": [".github/workflows/ci.yml", "scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/runbooks/postgres-ledger-integrity.md", "docs/testing.md"]},
        },
        formal_scope="runtime_constraints_back_formal_safety_invariants",
        hardening_frontier=("Add a migration drift checker if more migrations are introduced.",),
    ),
    Surface(
        id="rust_messaging_localstack",
        title="Rust Messaging and LocalStack",
        patterns=("crates/messaging/**", "scripts/localstack-init.sh"),
        required_axes=("source_inventory", "unit_or_property_tests", "runtime_or_smoke", "runtime_enforcement", "ci_gate", "documentation"),
        evidence={
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["crates/messaging/src/localstack.rs"]},
            "runtime_or_smoke": {"commands": ["make dev-up", "make smoke"], "paths": ["scripts/localstack-init.sh", ".github/workflows/ci.yml"]},
            "runtime_enforcement": {"paths": ["crates/messaging/src/localstack.rs", "scripts/localstack-init.sh"]},
            "ci_gate": {"paths": [".github/workflows/ci.yml", "scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/runbooks/localstack-sns-sqs.md"]},
        },
        formal_scope="messaging_idempotency_and_progress_modeled_abstractly",
        hardening_frontier=("Add deterministic LocalStack fanout replay tests if event schemas expand.",),
    ),
    Surface(
        id="rust_api_service",
        title="Rust API Service",
        patterns=("services/api/**",),
        required_axes=("source_inventory", "specification_or_contract", "unit_or_property_tests", "runtime_enforcement", "runtime_or_smoke", "ci_gate", "documentation"),
        evidence={
            "specification_or_contract": {"paths": ["spec/openapi.yaml"]},
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["services/api/tests/api_tests.rs"]},
            "runtime_enforcement": {"paths": ["services/api/src/middleware/mod.rs", "services/api/src/routes/mod.rs"]},
            "runtime_or_smoke": {"commands": ["make smoke", "make smoke-failure-paths"], "paths": ["scripts/smoke-create-sweep.sh"]},
            "ci_gate": {"paths": [".github/workflows/ci.yml", "scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/traceability.md", "docs/testing.md"]},
        },
        hardening_frontier=("Add generated OpenAPI client/server congruence checks if endpoint count grows.",),
    ),
    Surface(
        id="rust_workers_and_mocks",
        title="Rust Workers and Local External Simulators",
        patterns=("services/worker/**", "services/mock-transfer-agent/**"),
        required_axes=("source_inventory", "unit_or_property_tests", "runtime_or_smoke", "runtime_enforcement", "formal_projection", "ci_gate", "documentation"),
        evidence={
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["services/worker/src/workers/mod.rs", "services/mock-transfer-agent/src/main.rs"]},
            "runtime_or_smoke": {"commands": ["make smoke", "make smoke-failure-paths"], "paths": ["scripts/smoke-create-sweep.sh", "scripts/smoke-failure-paths.sh"]},
            "runtime_enforcement": {"paths": ["services/worker/src/workers/mod.rs"]},
            "formal_projection": {"paths": ["spec/refinement/liveness_coverage.yaml", "spec/refinement/invariant_coverage.yaml"]},
            "ci_gate": {"paths": [".github/workflows/ci.yml", "scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/liveness-verification.md", "docs/runbooks/failure-injection.md"]},
        },
        formal_scope="worker_progress_and_dedupe_tied_to_abstract_liveness_and_safety",
        hardening_frontier=("Add queue-level fault injection beyond current smoke paths if worker count grows.",),
    ),
    Surface(
        id="shared_rust_infra",
        title="Shared Rust Config and Observability",
        patterns=("crates/config/**", "crates/observability/**"),
        required_axes=("source_inventory", "unit_or_property_tests", "runtime_enforcement", "ci_gate", "documentation"),
        evidence={
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["crates/config/src/lib.rs"]},
            "runtime_enforcement": {"paths": ["crates/config/src/lib.rs", "crates/observability/src/lib.rs"]},
            "ci_gate": {"commands": ["make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/operations.md", "docs/security.md"]},
        },
        hardening_frontier=("Add metrics assertion tests if observability becomes behaviorally richer.",),
    ),
    Surface(
        id="frontend_console",
        title="React/TypeScript Operator Console",
        patterns=("web/react-console/**",),
        required_axes=("source_inventory", "specification_or_contract", "static_validation", "unit_or_property_tests", "ci_gate", "documentation"),
        evidence={
            "specification_or_contract": {"paths": ["spec/openapi.yaml", "web/react-console/src/api/client.ts"]},
            "static_validation": {"commands": ["pnpm --filter institutional-yield-react-console typecheck", "pnpm --filter institutional-yield-react-console lint"]},
            "unit_or_property_tests": {"commands": ["pnpm --filter institutional-yield-react-console test"], "paths": ["web/react-console/tests"]},
            "ci_gate": {"commands": ["make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/local-development.md", "docs/testing.md"]},
        },
        hardening_frontier=("Add browser E2E coverage if UI workflows become safety-significant.",),
    ),
    Surface(
        id="compose_runtime_and_smoke",
        title="Docker Compose Runtime and Smoke Gates",
        patterns=("docker-compose.yml", "scripts/dev-up.sh", "scripts/dev-down.sh", "scripts/dev-reset.sh", "scripts/smoke-create-sweep.sh", "scripts/smoke-failure-paths.sh"),
        required_axes=("source_inventory", "static_validation", "runtime_or_smoke", "ci_gate", "documentation"),
        evidence={
            "static_validation": {"commands": ["docker compose config --quiet"], "paths": ["docker-compose.yml"]},
            "runtime_or_smoke": {"commands": ["make dev-up", "make smoke", "make smoke-failure-paths"], "paths": ["scripts/smoke-create-sweep.sh", "scripts/smoke-failure-paths.sh"]},
            "ci_gate": {"paths": [".github/workflows/ci.yml"]},
            "documentation": {"paths": ["docs/local-development.md", "docs/testing.md"]},
        },
        hardening_frontier=("Add chaos-style smoke variants for transient LocalStack and database restarts.",),
    ),
    Surface(
        id="kubernetes_bootstrap",
        title="Kubernetes Local Bootstrap",
        patterns=("infra/k8s/**", "scripts/validate-k8s.sh", "scripts/smoke-k8s.sh", "scripts/install-kind-tooling.sh"),
        required_axes=("source_inventory", "static_validation", "runtime_or_smoke", "ci_gate", "documentation"),
        evidence={
            "static_validation": {"commands": ["make validate-k8s"], "paths": ["scripts/validate-k8s.sh"]},
            "runtime_or_smoke": {"commands": ["make k8s-up", "make k8s-smoke", "make k8s-down"], "paths": ["scripts/smoke-k8s.sh"]},
            "ci_gate": {"commands": ["make validate-k8s", "make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/runbooks/kubernetes-kind.md"]},
        },
        hardening_frontier=("Run kind smoke in CI when runner capacity and nested container behavior are acceptable.",),
    ),
    Surface(
        id="aws_certification_simulation",
        title="AWS Certification Simulation",
        patterns=(
            "infra/aws-simulation/**",
            "spec/certification/**",
            "scripts/aws-cert-*.sh",
            "scripts/validate-aws-certification.sh",
            "services/certifier/**",
        ),
        required_axes=(
            "source_inventory",
            "specification_or_contract",
            "static_validation",
            "unit_or_property_tests",
            "database_integration",
            "runtime_or_smoke",
            "runtime_enforcement",
            "drift_validator",
            "ci_gate",
            "documentation",
        ),
        evidence={
            "specification_or_contract": {"paths": ["spec/certification/aws_certification_coverage_map.json", "spec/certification/aws_certification_load.js"]},
            "static_validation": {"commands": ["make validate-aws-certification"], "paths": ["scripts/validate-aws-certification.sh"]},
            "unit_or_property_tests": {"commands": ["cargo test --workspace --all-features"], "paths": ["services/certifier/src/main.rs"]},
            "database_integration": {"paths": ["services/certifier/src/main.rs", "crates/persistence/migrations/20260616150400_initial.sql"]},
            "runtime_or_smoke": {"commands": ["make aws-cert-run"], "paths": ["scripts/aws-cert-run.sh", "spec/certification/aws_certification_load.js"]},
            "runtime_enforcement": {"paths": ["scripts/aws-cert-preflight.sh", "crates/config/src/lib.rs", "crates/messaging/src/localstack.rs"]},
            "drift_validator": {"commands": ["make validate-aws-certification"], "paths": ["scripts/validate-aws-certification.sh"]},
            "ci_gate": {"commands": ["make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/aws-certification.md", "docs/runbooks/aws-simulation.md"]},
        },
        formal_scope="cloud_simulation_evidence_for_existing_formal_and_runtime_invariants",
        hardening_frontier=("Run the opt-in AWS campaign in a sandbox account and attach collected evidence to the tracker before claiming certification success.",),
    ),
    Surface(
        id="docs_runbooks_adrs",
        title="Documentation, Runbooks, and ADRs",
        patterns=("docs/**", "scripts/validate-docs.sh"),
        exclude=("docs/formal-verification.md", "docs/liveness-verification.md"),
        required_axes=("source_inventory", "static_validation", "ci_gate", "documentation"),
        evidence={
            "static_validation": {"commands": ["make validate-docs"], "paths": ["scripts/validate-docs.sh"]},
            "ci_gate": {"commands": ["make validate-docs", "make validate"], "paths": ["scripts/validate-all.sh"]},
            "documentation": {"paths": ["docs/index.md", "docs/adr/README.md", "docs/runbooks/index.md"]},
        },
        hardening_frontier=("Add docs coverage checks for new runbooks as operational surfaces expand.",),
    ),
)


def git_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    files = []
    for line in result.stdout.splitlines():
        path = line.strip()
        if path and path not in DERIVED_SELF_ARTIFACTS:
            files.append(path)
    return sorted(files)


def matches(path: str, pattern: str) -> bool:
    return fnmatch.fnmatch(path, pattern)


def surface_matches(path: str, surface: Surface) -> bool:
    if any(matches(path, pattern) for pattern in surface.exclude):
        return False
    return any(matches(path, pattern) for pattern in surface.patterns)


def text_line_count(path: Path) -> int:
    try:
        return len(path.read_text(errors="ignore").splitlines())
    except OSError:
        return 0


def test_count(path: Path) -> int:
    if path.suffix != ".rs" and path.suffix not in {".ts", ".tsx"}:
        return 0
    try:
        text = path.read_text(errors="ignore")
    except OSError:
        return 0
    if path.suffix == ".rs":
        return len(re.findall(r"#\[(?:tokio::)?test\]", text))
    return len(re.findall(r"\b(?:it|test)\s*\(", text))


def kani_harnesses_by_path(root: Path, paths: list[str]) -> dict[str, list[str]]:
    harnesses: dict[str, list[str]] = {}
    for path_text in paths:
        path = root / path_text
        try:
            text = path.read_text(errors="ignore")
        except OSError:
            harnesses[path_text] = []
            continue
        harnesses[path_text] = re.findall(
            r"#\s*\[\s*kani::proof\s*\]\s*fn\s+([A-Za-z0-9_]+)\s*\(",
            text,
        )
    return harnesses


def command_known(command: str, make_targets: set[str], validate_all: str, ci_yaml: str) -> bool:
    if command.startswith("make "):
        target = command.split(maxsplit=1)[1]
        return target in make_targets
    return command in validate_all or command in ci_yaml or command.startswith(("cargo ", "pnpm ", "RUN_DATABASE_TESTS=", "docker "))


def evidence_present(root: Path, evidence: dict[str, list[str]], make_targets: set[str], validate_all: str, ci_yaml: str) -> bool:
    paths = evidence.get("paths") or []
    commands = evidence.get("commands") or []
    path_ok = all((root / path).exists() for path in paths)
    command_ok = all(command_known(command, make_targets, validate_all, ci_yaml) for command in commands)
    return path_ok and command_ok and bool(paths or commands)


def load_make_targets(root: Path) -> set[str]:
    makefile = (root / "Makefile").read_text()
    return set(re.findall(r"^([A-Za-z0-9_.-]+):", makefile, re.M))


def classify_files(files: list[str]) -> tuple[dict[str, list[str]], list[str], dict[str, list[str]]]:
    by_surface = {surface.id: [] for surface in SURFACES}
    unmapped: list[str] = []
    conflicts: dict[str, list[str]] = {}
    for path in files:
        matched = [surface.id for surface in SURFACES if surface_matches(path, surface)]
        if not matched:
            unmapped.append(path)
        elif len(matched) > 1:
            conflicts[path] = matched
        else:
            by_surface[matched[0]].append(path)
    return by_surface, unmapped, conflicts


def score(required_axes: tuple[str, ...], present_axes: list[str]) -> tuple[float, list[str]]:
    present = set(present_axes)
    missing = [axis for axis in required_axes if axis not in present]
    ratio = 1.0 if not required_axes else round((len(required_axes) - len(missing)) / len(required_axes), 4)
    return ratio, missing


def flatten_commands(evidence: dict[str, dict[str, list[str]]]) -> list[str]:
    commands: list[str] = []
    for record in evidence.values():
        for command in record.get("commands") or []:
            if command not in commands:
                commands.append(command)
    return commands


def flatten_paths(evidence: dict[str, dict[str, list[str]]]) -> list[str]:
    paths: list[str] = []
    for record in evidence.values():
        for path in record.get("paths") or []:
            if path not in paths:
                paths.append(path)
    return paths


def proof_ladder(surface: Surface, surface_files: list[str], present_axes: list[str], missing_axes: list[str]) -> dict[str, Any]:
    commands = flatten_commands(surface.evidence)
    evidence_paths = flatten_paths(surface.evidence)
    obligations = [
        {
            "id": f"{surface.id}.{axis}",
            "axis": axis,
            "status": "closed" if axis in present_axes else "needs_work",
            "closure_action": AXIS_ACTIONS.get(axis, f"Close missing axis: {axis}"),
        }
        for axis in surface.required_axes
    ]
    limits = []
    if surface.formal_scope == "none":
        limits.append("This surface is specified and enforced by contracts, validators, tests, runtime gates, or documentation, not by a dedicated theorem-prover model.")
    if surface.id.startswith("rust_") or surface.id == "shared_rust_infra":
        if "source_level_proof" in present_axes:
            limits.append("A targeted source-level proof is present for the narrow Rust kernel listed in evidence; no line-level formal proof of all Rust source is claimed.")
        else:
            limits.append("No line-level formal proof of all Rust source is claimed; Rust coverage is by tests, runtime enforcement, and refinement evidence where applicable.")
    if "runtime_or_smoke" in surface.required_axes:
        limits.append("Runtime evidence is local/CI LocalStack, Docker Compose, or kind-shaped evidence, not a production deployment proof.")

    return {
        "S0_objective": f"Specify, enforce, and validate the {surface.title} surface as part of the integrated yield control plane.",
        "S1_contract_or_spec": {
            "status": "closed" if "specification_or_contract" in present_axes else ("not_required" if "specification_or_contract" not in surface.required_axes else "needs_work"),
            "evidence_paths": surface.evidence.get("specification_or_contract", {}).get("paths", []),
        },
        "S2_executable_reference_or_validation_model": {
            "status": "closed" if any(axis in present_axes for axis in ["static_validation", "unit_or_property_tests", "runtime_or_smoke", "database_integration"]) else "needs_work",
            "commands": commands,
        },
        "S3_implementation_mapping": {
            "status": "closed" if surface_files else "needs_work",
            "file_count": len(surface_files),
            "representative_files": surface_files[:12],
            "formal_scope": surface.formal_scope,
            "evidence_paths": evidence_paths,
        },
        "S4_proof_obligations": obligations,
        "S5_machine_check": {
            "status": "closed" if "ci_gate" in present_axes and not missing_axes else "needs_work",
            "commands": commands + (["make validate"] if "make validate" not in commands else []),
        },
        "S6_assumptions_and_limits": {
            "limits": limits,
            "hardening_frontier": list(surface.hardening_frontier),
        },
    }


def build(root: Path) -> dict[str, Any]:
    files = git_files()
    by_surface, unmapped, conflicts = classify_files(files)
    make_targets = load_make_targets(root)
    validate_all = (root / "scripts/validate-all.sh").read_text() if (root / "scripts/validate-all.sh").exists() else ""
    ci_yaml = (root / ".github/workflows/ci.yml").read_text() if (root / ".github/workflows/ci.yml").exists() else ""
    formal_summary = {}
    formal_map_path = root / "spec/refinement/formal_coverage_map.json"
    if formal_map_path.exists():
        formal_summary = json.loads(formal_map_path.read_text()).get("summary", {})

    surfaces: list[dict[str, Any]] = []
    for surface in SURFACES:
        surface_files = by_surface[surface.id]
        lines = sum(text_line_count(root / path) for path in surface_files)
        tests = sum(test_count(root / path) for path in surface_files)
        rust_files = [path for path in surface_files if path.endswith(".rs")]
        present_axes = ["source_inventory"] if surface_files else []
        for axis, evidence in surface.evidence.items():
            if evidence_present(root, evidence, make_targets, validate_all, ci_yaml):
                present_axes.append(axis)
        coverage_score, missing_axes = score(surface.required_axes, present_axes)
        closure_status = "closed" if not missing_axes and surface_files else "needs_work"
        surfaces.append(
            {
                "id": surface.id,
                "title": surface.title,
                "closure_status": closure_status,
                "coverage_score": coverage_score,
                "formal_scope": surface.formal_scope,
                "file_count": len(surface_files),
                "line_count": lines,
                "rust_file_count": len(rust_files),
                "test_function_count_static": tests,
                "required_axes": list(surface.required_axes),
                "present_axes": present_axes,
                "missing_axes": missing_axes,
                "closure_actions": [AXIS_ACTIONS.get(axis, f"Close missing axis: {axis}") for axis in missing_axes],
                "hardening_frontier": list(surface.hardening_frontier),
                "evidence": surface.evidence,
                "proof_ladder": proof_ladder(surface, surface_files, present_axes, missing_axes),
                "files": surface_files,
            }
        )

    total_lines = sum(item["line_count"] for item in surfaces)
    total_files = sum(item["file_count"] for item in surfaces)
    closed = sum(1 for item in surfaces if item["closure_status"] == "closed")
    formalized = [item for item in surfaces if item["formal_scope"] != "none"]
    formalized_files = sum(item["file_count"] for item in formalized)
    formalized_lines = sum(item["line_count"] for item in formalized)
    rust_files = [path for path in files if path.endswith(".rs")]
    rust_lines = sum(text_line_count(root / path) for path in rust_files)
    rust_surfaces = [
        item for item in surfaces if item["id"].startswith("rust_") or item["id"] == "shared_rust_infra"
    ]
    source_proved_rust_surfaces = [
        item for item in rust_surfaces if "source_level_proof" in item["present_axes"]
    ]
    source_proof_harnesses = kani_harnesses_by_path(root, SOURCE_PROOF_PATHS)
    source_proof_harness_count = sum(len(items) for items in source_proof_harnesses.values())
    source_proof_obligations = []
    for obligation in SOURCE_PROOF_OBLIGATIONS:
        path = obligation["path"]
        harness = obligation["harness"]
        present = harness in source_proof_harnesses.get(path, [])
        source_proof_obligations.append(
            {
                **obligation,
                "status": "closed" if present else "needs_work",
            }
        )
    missing_source_proof_obligations = [
        obligation["id"]
        for obligation in source_proof_obligations
        if obligation["status"] != "closed"
    ]
    source_level_claims = {
        "line_level_rust_formal_proof_ratio": 0.0,
        "targeted_source_proof_rust_surface_count": len(source_proved_rust_surfaces),
        "targeted_source_proof_rust_surface_ratio": round(len(source_proved_rust_surfaces) / len(rust_surfaces), 4) if rust_surfaces else 1.0,
        "targeted_source_proofs": [
            {
                "tool": "Kani",
                "surface_id": "rust_domain_core",
                "crate": "institutional-yield-domain",
                "paths": SOURCE_PROOF_PATHS,
                "harness_count": source_proof_harness_count,
                "obligation_count": len(source_proof_obligations),
                "closed_obligation_count": len(source_proof_obligations)
                - len(missing_source_proof_obligations),
                "obligations": source_proof_obligations,
                "missing_obligations": missing_source_proof_obligations,
                "command": "make validate-source-proofs",
                "claim": "Bounded source-level proof over the finite built-in asset classifier, sweep transition, Rust-to-TLA action mapping, and AWS certification admission kernels.",
                "status": "closed"
                if any(item["id"] == "rust_domain_core" for item in source_proved_rust_surfaces)
                and not missing_source_proof_obligations
                else "needs_work",
            }
        ],
        "remaining_source_level_boundaries": [
            {
                "surface_id": item["id"],
                "status": "covered_by_other_gates",
                "reason": SOURCE_PROOF_BOUNDARY_REASONS.get(
                    item["id"],
                    "No narrow pure finite Rust kernel has been identified for source-level proof on this surface.",
                ),
            }
            for item in rust_surfaces
            if item not in source_proved_rust_surfaces
        ],
        "reason": "The repo proves an abstract protocol, checks Rust trace/refinement evidence, and now has targeted Kani source proofs for pure finite domain kernels; it still does not prove every Rust source line.",
        "abstract_rust_to_tla_refinement": formal_summary.get("rust_to_tla_refinement", {}),
    }

    return {
        "version": 1,
        "artifact": "repo_surface_coverage_map",
        "source_of_truth": [
            "git ls-files --cached --others --exclude-standard",
            "Makefile",
            "scripts/validate-all.sh",
            ".github/workflows/ci.yml",
            "spec/refinement/formal_coverage_map.json",
        ],
        "excluded_derived_self_artifacts": sorted(DERIVED_SELF_ARTIFACTS),
        "closure_semantics": {
            "closed": "All required validation axes for this surface have executable evidence and the surface owns at least one file.",
            "needs_work": "The surface has unmapped files, missing required axes, missing evidence, or no assigned files.",
        },
        "integrated_verification_goal": {
            "intent": "Use JSON to track all major repo surfaces, specify each surface at the strongest appropriate abstraction level, enforce the corresponding rule at code or runtime level, and keep every mapping under CI drift checks.",
            "proof_boundary": "The integrated system is formally verified at the abstract protocol level with TLAPS/TLC and connected to implementation by refinement-lite Rust traces, validators, runtime enforcement, and smoke gates.",
            "non_claim": "This map does not claim full source-level theorem-prover verification of every Rust, TypeScript, YAML, shell, or Markdown line.",
        },
        "summary": {
            "surface_count": len(surfaces),
            "closed_surface_count": closed,
            "needs_work_surface_count": len(surfaces) - closed,
            "surface_closure_ratio": round(closed / len(surfaces), 4) if surfaces else 1.0,
            "mapped_file_count": total_files,
            "unmapped_file_count": len(unmapped),
            "conflicting_file_count": len(conflicts),
            "all_mappable_file_count": len(files),
            "file_mapping_ratio": round(total_files / len(files), 4) if files else 1.0,
            "line_count": total_lines,
            "formalized_surface_count": len(formalized),
            "formalized_surface_ratio": round(len(formalized) / len(surfaces), 4) if surfaces else 1.0,
            "formalized_file_count": formalized_files,
            "formalized_file_ratio": round(formalized_files / total_files, 4) if total_files else 1.0,
            "formalized_line_count": formalized_lines,
            "formalized_line_ratio": round(formalized_lines / total_lines, 4) if total_lines else 1.0,
            "rust_file_count": len(rust_files),
            "rust_line_count": rust_lines,
            "rust_test_function_count_static": sum(test_count(root / path) for path in rust_files),
            "source_level_rust_verification": source_level_claims,
            "formal_coverage_summary": formal_summary,
        },
        "unmapped_files": unmapped,
        "conflicting_files": conflicts,
        "surfaces": surfaces,
    }


def render(payload: dict[str, Any]) -> str:
    return json.dumps(payload, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate or check whole-repository surface coverage JSON.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="JSON output path")
    parser.add_argument("--check", action="store_true", help="Fail if output is stale or coverage has unmapped/conflicting files")
    args = parser.parse_args()

    root = Path.cwd()
    output = root / args.output
    payload = build(root)
    rendered = render(payload)

    if args.check:
        if payload["summary"]["unmapped_file_count"] != 0:
            raise SystemExit(f"Unmapped files in repo surface coverage: {payload['unmapped_files']}")
        if payload["summary"]["conflicting_file_count"] != 0:
            raise SystemExit(f"Files match multiple surfaces: {payload['conflicting_files']}")
        needs_work = [item["id"] for item in payload["surfaces"] if item["closure_status"] != "closed"]
        if needs_work:
            raise SystemExit(f"Repo surfaces need coverage work: {needs_work}")
        if not output.exists():
            raise SystemExit(f"Missing generated repo surface coverage map: {args.output}")
        if output.read_text() != rendered:
            raise SystemExit(
                f"{args.output} is stale. Regenerate with ./scripts/generate-repo-surface-coverage-map.py"
            )
        print("Repository surface coverage JSON map is current.")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered)
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
