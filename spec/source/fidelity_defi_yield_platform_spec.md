You are Codex acting as a principal-level autonomous software engineer, architect, technical writer, QA engineer, DevOps engineer, and security-minded platform engineer.

Your task is to turn the attached specification into a production-grade, locally runnable, fully tested Rust + SNS/SQS microservices system with a React/TypeScript frontend. You must work gate-by-gate, maintain a tracker file, generate and validate specifications before implementation, justify major decisions through ADRs, and build an agentic documentation system that future agents and humans can use to continue the project safely.

The attached source specification is authoritative. It describes an Institutional DeFi Yield Control Plane on AWS, using Rust backend services, SQL-backed financial state, React/TypeScript frontend surfaces, AWS-style deployment, Docker, Kubernetes, SNS/SQS-style asynchronous workers, resilient messaging, OpenAPI, AsyncAPI, domain state-machine specs, SQL ledger design, reconciliation, testing, CI/CD gates, runbooks, observability, and ADR-backed architectural decisions.

Do not merely summarize, scaffold, or leave TODOs. Implement the system until it runs locally and passes the required gates. If the repository is empty, create the full repository. If the repository already contains files, inspect them first, preserve user work, and adapt the plan.

Use best practices, but justify them with ADRs. Avoid real AWS calls. The local implementation must use LocalStack for SNS/SQS, local Postgres for durable state, Docker Compose for the simplest full-stack local environment, and Kubernetes manifests for local cluster bootstrapping with kind or equivalent. All financial/institutional functionality is a local simulation and must not claim to be legal, investment, accounting, tax, or regulatory advice.

================================================================================
OPERATING RULES
================================================================================

1. Do not ask the user clarifying questions unless blocked by missing permissions or impossible local environment constraints.
2. Make reasonable senior-engineering choices and document them.
3. Before editing code, create and maintain a tracker file at:

   AGENT_TRACKER.md

4. Update AGENT_TRACKER.md:
   - before starting each gate;
   - after completing each gate;
   - after any failed command;
   - after any design decision;
   - after any deviation from the requested plan;
   - before final response.

5. Never proceed past a gate unless:
   - the gate’s success criteria pass; or
   - the failure is documented in AGENT_TRACKER.md with the exact command, error, root-cause hypothesis, mitigation, and follow-up gate.

6. Prefer project-local tooling and reproducible scripts.
7. Install missing local dependencies when safe and possible.
8. If a tool requires elevated OS permissions or cannot be installed non-interactively, do not silently skip it. Record the issue in AGENT_TRACKER.md and provide exact user-run commands in scripts/bootstrap-local.sh and docs/bootstrap.md.
9. Do not use real AWS resources. All AWS SDK clients must default to LocalStack endpoints in local/dev mode.
10. Do not commit secrets.
11. Do not store real private keys.
12. Do not create financial claims that FIDD itself earns yield. The UI, API, docs, and domain model must distinguish payment/stablecoin cash rails from separate yield-bearing products or positions.
13. Direct status mutation is forbidden. All order lifecycle changes must go through a Rust domain transition function.
14. Financial writes must support idempotency.
15. Workers must be safe under at-least-once delivery.
16. Every major decision must have an ADR.
17. Every requirement derived from the attached spec must be traceable to code, tests, specs, docs, or an explicit deferral.

================================================================================
PRIMARY GOAL
================================================================================

Build a local, production-shaped demo system called:

  institutional-yield-control-plane

The system must demonstrate:

1. Rust microservices and shared crates.
2. Axum HTTP API.
3. Tokio async runtime.
4. Postgres durable state.
5. SQLx migrations.
6. LocalStack SNS/SQS fanout.
7. SQS workers with retries, idempotency, dead-letter handling, and graceful shutdown.
8. Domain state machine for sweep orders.
9. OpenAPI REST contract.
10. AsyncAPI event contract.
11. JSON Schema event payloads where useful.
12. React/TypeScript frontend.
13. Docker Compose full-stack local run.
14. Kubernetes manifests for local bootstrapping.
15. Agentic docs system.
16. ADRs for all important choices.
17. Unit, property, integration, contract, frontend, and end-to-end smoke tests.
18. CI pipeline matching the local gates.

The local happy-path workflow must work end-to-end:

  React UI
    -> Rust API
    -> Postgres transaction
    -> outbox event
    -> SNS topic in LocalStack
    -> SQS queues in LocalStack
    -> Rust worker consumes message
    -> mock transfer-agent confirmation
    -> position booking
    -> reconciliation worker
    -> Active sweep order
    -> React UI shows timeline and status

The local failure-path workflow must also be demonstrable:

  duplicate idempotency key
    -> no duplicate order

  duplicate external confirmation
    -> no duplicate position

  reconciliation mismatch
    -> reconciliation break opened

  attempted FIDD yield accrual
    -> rejected by domain or persistence rule

================================================================================
REPOSITORY STRUCTURE
================================================================================

Create or converge toward this structure:

  AGENT_TRACKER.md
  AGENTS.md
  README.md
  Makefile
  justfile
  docker-compose.yml
  .env.example
  .gitignore
  .editorconfig
  .github/
    workflows/
      ci.yml
  scripts/
    bootstrap-local.sh
    check-tools.sh
    localstack-init.sh
    dev-up.sh
    dev-down.sh
    dev-reset.sh
    smoke-create-sweep.sh
    smoke-failure-paths.sh
    smoke-k8s.sh
    validate-specs.sh
    validate-docs.sh
    validate-all.sh
    install-kind-tooling.sh
  spec/
    source/
      fidelity_defi_yield_platform_spec.md
    openapi.yaml
    asyncapi.yaml
    domain/
      sweep_order.machine.yaml
    schemas/
      events/
        event-envelope.schema.json
        sweep-order-created.v1.schema.json
        sweep-cash-locked.v1.schema.json
        transfer-agent-confirmed.v1.schema.json
        position-booked.v1.schema.json
        reconciliation-break-opened.v1.schema.json
    tla/
      no_double_sweep.tla
    diagrams/
      architecture.mmd
      sweep-order-state-machine.mmd
      local-runtime.mmd
  docs/
    index.md
    bootstrap.md
    architecture.md
    local-development.md
    production-readiness.md
    testing.md
    operations.md
    security.md
    traceability.md
    agentic/
      index.md
      working-agreement.md
      implementation-log.md
      gate-history.md
      docs-generation.md
    adr/
      README.md
      0001-use-rust-workspace-and-shared-domain-crates.md
      0002-use-localstack-for-local-sns-sqs.md
      0003-use-postgres-sqlx-and-append-only-ledger.md
      0004-enforce-state-machine-in-domain-layer.md
      0005-use-outbox-inbox-for-resilient-messaging.md
      0006-use-react-typescript-generated-api-client.md
      0007-use-docker-compose-for-primary-local-runtime.md
      0008-provide-kind-kubernetes-bootstrap.md
      0009-use-mock-transfer-agent-and-chain-observer-locally.md
      0010-no-real-aws-calls-in-local-mode.md
    runbooks/
      transfer-agent-outage.md
      localstack-outage.md
      worker-retry-storm.md
      reconciliation-break.md
      duplicate-callback.md
      cash-locked-too-long.md
      emergency-pause.md
      local-kubernetes-recovery.md
  crates/
    domain/
      Cargo.toml
      src/
        lib.rs
        asset.rs
        money.rs
        sweep.rs
        ledger.rs
        events.rs
        invariants.rs
        errors.rs
      tests/
        sweep_state_machine_tests.rs
        sweep_property_tests.rs
        ledger_invariant_tests.rs
    persistence/
      Cargo.toml
      migrations/
      src/
        lib.rs
        db.rs
        repositories.rs
        outbox.rs
        inbox.rs
        idempotency.rs
    messaging/
      Cargo.toml
      src/
        lib.rs
        sns.rs
        sqs.rs
        envelope.rs
        localstack.rs
    observability/
      Cargo.toml
      src/
        lib.rs
        tracing.rs
        metrics.rs
    config/
      Cargo.toml
      src/
        lib.rs
  services/
    api/
      Cargo.toml
      Dockerfile
      src/
        main.rs
        routes/
        middleware/
        error.rs
        openapi.rs
    worker/
      Cargo.toml
      Dockerfile
      src/
        main.rs
        workers/
          outbox_publisher.rs
          transfer_agent_worker.rs
          reconciliation_worker.rs
          notification_worker.rs
          chain_watcher.rs
    mock-transfer-agent/
      Cargo.toml
      Dockerfile
      src/
        main.rs
  web/
    react-console/
      package.json
      pnpm-lock.yaml
      vite.config.ts
      tsconfig.json
      Dockerfile
      src/
        main.tsx
        App.tsx
        api/
        components/
        pages/
        hooks/
        styles/
      tests/
      e2e/
  infra/
    docker/
      postgres/
      localstack/
    k8s/
      base/
        namespace.yaml
        configmap.yaml
        postgres.yaml
        localstack.yaml
        api-deployment.yaml
        api-service.yaml
        worker-deployment.yaml
        mock-transfer-agent-deployment.yaml
        web-deployment.yaml
        web-service.yaml
        networkpolicy.yaml
        pdb.yaml
      overlays/
        local/
          kustomization.yaml
          ingress.yaml
        aws-shaped/
          kustomization.yaml
          serviceaccounts.yaml
          hpa.yaml
          keda-scaledobjects.yaml
          iam-policy-examples.md
      kind/
        cluster.yaml

If a slightly different structure is needed for technical correctness, use it, but record the rationale in an ADR and AGENT_TRACKER.md.

================================================================================
TRACKER FILE REQUIREMENTS
================================================================================

Create AGENT_TRACKER.md immediately.

It must contain:

  # Agent Tracker

  ## Mission
  Brief mission statement.

  ## Source Spec
  File/path used as source of truth.

  ## Current Gate
  Gate name, status, start time.

  ## Gate Status Table
  Columns:
    Gate
    Objective
    Status: Not Started / In Progress / Blocked / Passed / Failed / Deferred
    Evidence
    Last Updated

  ## Requirements Traceability Summary
  A compact list of source requirements and where they are implemented.

  ## Commands Run
  Append-only log:
    timestamp
    command
    working directory
    result
    notes

  ## Decisions Made
  Link to ADRs.

  ## Defects / Failures
  Append-only log of failures and fixes.

  ## Environment
  OS, shell, Rust version, Node version, Docker version, kubectl/kind versions if available.

  ## Final Verification
  Checklist and evidence.

Maintain this file throughout the task.

================================================================================
AGENTIC DOCUMENTATION SYSTEM
================================================================================

Create an agentic documentation system that future agents can use without re-reading the entire repo.

Minimum files:

1. AGENTS.md
   - How future agents should operate.
   - Required gates.
   - Do-not-violate rules.
   - Commands to validate the repo.
   - Where specs, ADRs, and tracker live.

2. docs/agentic/index.md
   - Navigation for agents.
   - System overview.
   - Current implementation state.
   - Known boundaries.

3. docs/traceability.md
   - Requirement-to-artifact mapping.
   - Example:
     Requirement: idempotent sweep creation.
     Artifacts: OpenAPI header, API middleware, DB unique index, domain tests, integration tests, smoke script.

4. docs/agentic/gate-history.md
   - Gate outcomes and evidence.
   - Keep in sync with AGENT_TRACKER.md at the end.

5. docs/adr/README.md
   - ADR index.
   - ADR status legend.
   - ADR template.

6. docs/runbooks/*.md
   - Operational runbooks for the local and production-shaped system.

Add scripts/validate-docs.sh to check:
  - required docs exist;
  - ADR index links all ADRs;
  - traceability document exists;
  - no broken obvious relative links where practical;
  - no docs contain unresolved TODO/FIXME unless explicitly allowed in AGENT_TRACKER.md.

================================================================================
ARCHITECTURE DECISION RECORDS
================================================================================

Every material design decision must have an ADR.

Use this ADR template:

  # ADR-NNNN: Title

  ## Status
  Proposed / Accepted / Superseded

  ## Context
  What problem or constraint led to this decision?

  ## Decision
  What is the decision?

  ## Options Considered
  - Option A
  - Option B
  - Option C

  ## Rationale
  Why this option?

  ## Consequences
  Positive and negative consequences.

  ## Validation
  How this decision is validated by tests, scripts, docs, or runtime behavior.

Initial ADRs must cover at least:

1. Rust workspace with shared domain crates and multiple deployable services.
2. LocalStack for local SNS/SQS.
3. Postgres + SQLx + migrations for durable state.
4. Domain state machine as the source of transition correctness.
5. Outbox/inbox/idempotency for resilient messaging.
6. React/TypeScript with API contract types.
7. Docker Compose as primary local runtime.
8. kind/Kubernetes manifests for local bootstrapping.
9. Local mock transfer agent and local chain watcher.
10. No real AWS calls in local mode.
11. How production AWS/EKS/SNS/SQS/IAM would differ from local simulation.
12. How financial safety invariants are enforced.

================================================================================
GATES
================================================================================

You must implement the project through these gates.

Do not skip gates. Mark each gate in AGENT_TRACKER.md.

--------------------------------------------------------------------------------
GATE 0: Repository and Environment Discovery
--------------------------------------------------------------------------------

Objective:
  Understand the current repo and local environment without making destructive changes.

Tasks:
  - Run pwd, ls, git status if available.
  - Detect OS and shell.
  - Detect installed tools:
      rustc
      cargo
      node
      npm
      pnpm
      docker
      docker compose
      make
      just
      jq
      curl
      aws
      awslocal
      kubectl
      kind
      helm
  - Create AGENT_TRACKER.md.
  - Record all findings.

Success criteria:
  - AGENT_TRACKER.md exists and includes environment snapshot.
  - No destructive changes made.

--------------------------------------------------------------------------------
GATE 1: Source Spec Ingestion and Requirements Extraction
--------------------------------------------------------------------------------

Objective:
  Preserve the attached source spec and extract implementable requirements.

Tasks:
  - Locate the attached source spec. Expected filename may be:
      fidelity_defi_yield_platform_spec(1).md
      fidelity_defi_yield_platform_spec.md
      or an attached/session file.
  - Copy it into:
      spec/source/fidelity_defi_yield_platform_spec.md
  - Create docs/traceability.md.
  - Extract requirements into categories:
      domain model
      lifecycle state machine
      API
      events
      persistence
      workers
      frontend
      local runtime
      Kubernetes
      tests
      docs
      security
      observability
      runbooks
  - Mark each requirement as:
      Implemented now
      Implemented as local mock
      Documented production pattern
      Deferred with reason

Success criteria:
  - Source spec is stored in spec/source/.
  - docs/traceability.md exists.
  - AGENT_TRACKER.md lists top-level requirements.

--------------------------------------------------------------------------------
GATE 2: Tooling and Local Bootstrap
--------------------------------------------------------------------------------

Objective:
  Make the project self-bootstrapping.

Tasks:
  - Create scripts/check-tools.sh.
  - Create scripts/bootstrap-local.sh.
  - Create .env.example.
  - Create Makefile and justfile.
  - Prefer these commands:
      make bootstrap
      make check-tools
      make validate
      make dev-up
      make dev-down
      make test
      make smoke
      make k8s-up
      make k8s-smoke
  - justfile may wrap the same commands if just is installed.
  - Install project-local or user-level tools where safe:
      Rust toolchain if rustup exists or can be installed safely
      cargo-nextest
      sqlx-cli
      cargo-deny or cargo-audit
      Node package manager via corepack/pnpm
      OpenAPI/AsyncAPI lint tools through npm dev dependencies
      kind/kubectl/helm through scripts where feasible
  - Docker installation may require admin privileges. If missing, provide exact OS-specific guidance in docs/bootstrap.md rather than attempting unsafe privileged installation.

Success criteria:
  - make check-tools runs.
  - scripts are executable.
  - docs/bootstrap.md explains local setup.
  - AGENT_TRACKER.md records installed and missing tools.

--------------------------------------------------------------------------------
GATE 3: Specifications Before Implementation
--------------------------------------------------------------------------------

Objective:
  Create validated specs before writing the application logic.

Tasks:
  - Create spec/domain/sweep_order.machine.yaml from the attached spec.
  - Create spec/openapi.yaml.
  - Create spec/asyncapi.yaml.
  - Create JSON schemas for the event envelope and key events.
  - Create Mermaid diagrams:
      spec/diagrams/architecture.mmd
      spec/diagrams/sweep-order-state-machine.mmd
      spec/diagrams/local-runtime.mmd
  - Create spec/tla/no_double_sweep.tla as a design-time formal model skeleton.
  - Create scripts/validate-specs.sh.
  - Validate:
      OpenAPI syntax.
      AsyncAPI syntax if tool available.
      JSON Schema syntax.
      domain state machine YAML structure.
      required status enum consistency across state-machine and OpenAPI.
      required event consistency across state-machine emits and AsyncAPI channels where practical.

Minimum OpenAPI endpoints:
  - GET /health
  - GET /ready
  - POST /sweep-policies
  - GET /sweep-policies/{account_id}
  - POST /sweep-orders
  - GET /sweep-orders/{order_id}
  - POST /sweep-orders/{order_id}/approve
  - POST /sweep-orders/{order_id}/cancel
  - POST /redemptions
  - GET /accounts/{account_id}/positions
  - GET /accounts/{account_id}/income
  - GET /reconciliation-breaks
  - POST /reconciliation-breaks/{break_id}/resolve
  - GET /audit-events

All write endpoints must require:
  - Idempotency-Key
  - Correlation-Id

Minimum AsyncAPI channels/events:
  - sweep.order.created.v1
  - sweep.eligibility.checked.v1
  - sweep.disclosures.checked.v1
  - sweep.order.approved.v1
  - sweep.cash.locked.v1
  - sweep.subscription.submitted.v1
  - sweep.transfer_agent.confirmed.v1
  - sweep.chain_mirror.observed.v1
  - sweep.position.booked.v1
  - sweep.reconciled.v1
  - sweep.active.v1
  - redemption.requested.v1
  - redemption.submitted.v1
  - redemption.confirmed.v1
  - redemption.cash_credited.v1
  - reconciliation.break.opened.v1
  - reconciliation.break.resolved.v1
  - audit.event.recorded.v1

Success criteria:
  - make validate-specs passes.
  - Specs are referenced from README.md and docs/index.md.
  - AGENT_TRACKER.md records validation commands.

--------------------------------------------------------------------------------
GATE 4: Rust Workspace and Domain Core
--------------------------------------------------------------------------------

Objective:
  Implement the core financial/domain model safely.

Tasks:
  - Create a Rust workspace.
  - Create crates/domain.
  - Implement:
      Asset enum: USD, FIDD, ETH, BTC, plus ProductAsset if needed.
      Money/Decimal type using rust_decimal or a justified fixed-point representation.
      SweepStatus enum matching spec/domain/sweep_order.machine.yaml.
      SweepCommand enum.
      GuardContext.
      TransitionOutcome.
      TransitionError.
      transition(current, command, ctx) function.
      LedgerEntry model.
      Ledger invariant checks.
      Event envelope types.
  - Ensure no code can book position without official confirmation for transfer-agent-governed products.
  - Ensure yield accrual cannot target FIDD balance as the yield-bearing source.
  - Ensure Active is only reachable after Reconciled.
  - Ensure CashCredited/Settled path cannot happen without redemption confirmation.
  - Add generated or handwritten conformance tests ensuring Rust statuses match the YAML machine.

Required tests:
  - Valid transition tests.
  - Invalid transition tests.
  - Property tests using proptest.
  - Ledger balancing tests.
  - No yield on FIDD tests.
  - No position without transfer-agent confirmation tests.

Success criteria:
  - cargo fmt passes.
  - cargo clippy --workspace --all-targets --all-features -- -D warnings passes.
  - cargo test --workspace passes for domain crate.
  - AGENT_TRACKER.md records all commands.

--------------------------------------------------------------------------------
GATE 5: Persistence, SQL Migrations, Idempotency, Outbox/Inbox
--------------------------------------------------------------------------------

Objective:
  Create durable financial state.

Tasks:
  - Create crates/persistence.
  - Use Postgres and SQLx.
  - Add migrations for:
      accounts
      sweep_policies
      sweep_orders
      state_transitions
      ledger_entries
      positions
      reconciliation_breaks
      outbox_events
      inbox_messages
      audit_events
      idempotency_records
  - Add constraints:
      unique account_id + idempotency_key for sweep_orders;
      unique external_order_ref where not null;
      unique transfer_agent_confirmation_ref where not null;
      ledger numeric precision;
      valid debit_credit values;
      valid direction values;
      reasonable status checks where maintainable.
  - Implement repository methods with explicit transactions.
  - Implement idempotency lookup and replay behavior.
  - Implement outbox insert in the same transaction as state change.
  - Implement inbox deduplication for consumed messages.
  - Implement tests against local Postgres via docker compose or testcontainers.

Success criteria:
  - docker compose can start Postgres.
  - migrations apply cleanly.
  - persistence tests pass.
  - duplicate idempotency key returns/reuses existing result rather than creating duplicate order.
  - duplicate external confirmation cannot double-book.
  - AGENT_TRACKER.md records evidence.

--------------------------------------------------------------------------------
GATE 6: Messaging with LocalStack SNS/SQS
--------------------------------------------------------------------------------

Objective:
  Implement resilient local AWS-style messaging.

Tasks:
  - Create crates/messaging.
  - Use AWS SDK for Rust for SNS/SQS, configured for LocalStack in local mode.
  - Create scripts/localstack-init.sh to create:
      SNS topic: domain-events
      SQS queue: transfer-agent-worker-queue
      SQS queue: reconciliation-worker-queue
      SQS queue: notification-worker-queue
      SQS queue: chain-watcher-queue
      DLQs for each worker queue
      subscriptions from SNS topic to each SQS queue
  - Add raw message delivery or clearly handle SNS envelope format.
  - Add event envelope:
      event_id
      event_type
      schema_version
      aggregate_id
      correlation_id
      causation_id
      idempotency_key_hash where applicable
      occurred_at
      payload
  - Implement SNS publisher.
  - Implement SQS long-poll consumer.
  - Implement retry/backoff helpers.
  - Implement delete only after successful processing.
  - Implement poison-message handling / DLQ policy through LocalStack queue redrive where supported.
  - Ensure local mode fails fast if it would hit real AWS.

Success criteria:
  - LocalStack starts through docker compose.
  - scripts/localstack-init.sh creates topic, queues, subscriptions.
  - A test event published to SNS arrives in subscribed SQS queues.
  - messaging tests pass.
  - AGENT_TRACKER.md records commands.

--------------------------------------------------------------------------------
GATE 7: Rust API Service
--------------------------------------------------------------------------------

Objective:
  Implement the HTTP API service.

Tasks:
  - Create services/api with Axum.
  - Implement routes from spec/openapi.yaml.
  - Add middleware:
      correlation ID
      request logging
      idempotency-key validation on writes
      error mapping
  - Add health and readiness endpoints.
  - Add create sweep policy.
  - Add create sweep order.
  - Add approve/cancel routes.
  - Add read order/timeline.
  - Add positions and income read endpoints.
  - Add reconciliation breaks endpoints.
  - Add audit event query endpoint.
  - Command handler flow:
      validate request
      read idempotency record
      start DB transaction
      load/create aggregate
      call domain transition
      write transition
      write ledger entries if applicable
      write outbox event
      commit
      return response
  - Do not publish to SNS directly inside the request transaction. Use outbox.
  - Add OpenAPI conformance check where practical.

Success criteria:
  - API compiles.
  - API tests pass.
  - POST /sweep-orders requires Idempotency-Key and Correlation-Id.
  - Replaying same request with same Idempotency-Key returns the same logical order.
  - Invalid transitions return typed errors.
  - AGENT_TRACKER.md records evidence.

--------------------------------------------------------------------------------
GATE 8: Workers and Local External Simulators
--------------------------------------------------------------------------------

Objective:
  Implement asynchronous processing and external system simulation.

Tasks:
  - Create services/worker.
  - Worker binary may support WORKER_KIND:
      outbox-publisher
      transfer-agent
      reconciliation
      chain-watcher
      notification
  - Create services/mock-transfer-agent.
  - mock-transfer-agent must:
      accept subscription requests with external idempotency key;
      return stable confirmation for repeated idempotency key;
      support injected mismatch/failure modes for tests;
      expose health endpoint.
  - outbox-publisher:
      leases pending outbox rows;
      publishes to SNS;
      marks published;
      retries safely.
  - transfer-agent-worker:
      consumes relevant events;
      calls mock-transfer-agent;
      submits ConfirmTransferAgent command;
      writes next outbox event.
  - chain-watcher:
      simulates optional chain mirror observation.
  - reconciliation-worker:
      compares internal state, mock transfer-agent state, and simulated chain observation;
      marks Reconciled/Active on match;
      opens reconciliation break on mismatch.
  - notification-worker:
      consumes events and records notification/audit projection locally.
  - All workers must:
      long-poll SQS;
      use bounded concurrency;
      delete message only after success;
      record inbox deduplication;
      support graceful shutdown;
      emit structured logs;
      expose health where relevant or document why not.

Success criteria:
  - Worker tests pass.
  - Happy-path workflow can reach Active.
  - Duplicate SQS delivery does not duplicate position or transition.
  - Failure injection can open a reconciliation break.
  - AGENT_TRACKER.md records evidence.

--------------------------------------------------------------------------------
GATE 9: React/TypeScript Frontend
--------------------------------------------------------------------------------

Objective:
  Build an operator/client console.

Tasks:
  - Create web/react-console using Vite + React + TypeScript.
  - Use pnpm.
  - Generate or maintain typed API client from OpenAPI where practical.
  - Use TanStack Query or a justified equivalent for server state.
  - Implement pages:
      Dashboard
      Create Sweep Policy
      Create Sweep Order
      Sweep Order Detail with timeline
      Positions
      Reconciliation Breaks
      System Health
      Dev Failure Injection panel for local demo only
  - UI must clearly state:
      FIDD balance does not itself earn yield.
      Yield belongs to separate fund shares, staking positions, or approved strategies.
      Pending, active, settled, and exception states are distinct.
      Transfer-agent confirmation is authoritative in this local FYOXX-like flow.
  - Write frontend tests:
      component tests
      API client tests or mocks
      Playwright smoke test if feasible

Success criteria:
  - pnpm install works.
  - pnpm typecheck passes.
  - pnpm lint passes if lint configured.
  - pnpm test passes.
  - React app can create and display a sweep order through the local API.
  - AGENT_TRACKER.md records evidence.

--------------------------------------------------------------------------------
GATE 10: Docker Compose Full Local Runtime
--------------------------------------------------------------------------------

Objective:
  Make the entire system run locally with one command.

Tasks:
  - Create docker-compose.yml with:
      postgres
      localstack
      api
      outbox-publisher
      transfer-agent-worker
      reconciliation-worker
      chain-watcher
      notification-worker
      mock-transfer-agent
      react-console
  - Add healthchecks.
  - Add dependency ordering where useful.
  - Add scripts/dev-up.sh and scripts/dev-down.sh.
  - Add scripts/dev-reset.sh for clearing local state.
  - Add scripts/smoke-create-sweep.sh:
      start from clean environment;
      create account/seed if needed;
      create sweep policy;
      create sweep order with Idempotency-Key;
      wait for Active;
      fetch order timeline;
      fetch positions;
      verify no reconciliation breaks.
  - Add scripts/smoke-failure-paths.sh:
      duplicate idempotency key does not create duplicate;
      duplicate confirmation does not double-book;
      mismatch opens reconciliation break;
      attempted FIDD yield accrual is rejected.

Success criteria:
  - make dev-up starts the stack.
  - make smoke passes.
  - make dev-down stops the stack.
  - Docker images build locally.
  - AGENT_TRACKER.md records exact commands and results.

--------------------------------------------------------------------------------
GATE 11: Kubernetes Local Bootstrapping
--------------------------------------------------------------------------------

Objective:
  Provide Kubernetes manifests and local cluster bootstrap.

Tasks:
  - Create infra/k8s/base manifests for:
      namespace
      configmap
      postgres
      localstack
      api deployment/service
      mock-transfer-agent deployment/service
      worker deployments
      web deployment/service
      network policy where supported
      pod disruption budget where meaningful
  - Create infra/k8s/overlays/local using kustomize.
  - Create infra/k8s/kind/cluster.yaml.
  - Create scripts/install-kind-tooling.sh.
  - Create make k8s-up:
      create kind cluster if missing;
      build local images;
      load images into kind;
      deploy manifests;
      initialize LocalStack resources inside cluster;
      wait for readiness.
  - Create make k8s-smoke:
      port-forward API and web;
      run the same happy-path smoke test.
  - Create infra/k8s/overlays/aws-shaped examples:
      service accounts
      resource requests/limits
      HPA for API
      KEDA ScaledObject examples for SQS workers
      IAM policy examples as documentation
  - Do not require real AWS for local Kubernetes.

Success criteria:
  - Kubernetes manifests validate with kubectl dry-run where possible.
  - kind local deployment works if Docker/kind are available.
  - If local environment cannot run kind, document exact blocker and still provide complete manifests and scripts.
  - AGENT_TRACKER.md records evidence.

--------------------------------------------------------------------------------
GATE 12: Observability, Security, and Operations
--------------------------------------------------------------------------------

Objective:
  Add production-shaped operational practices.

Tasks:
  - Add structured tracing with tracing/tracing-subscriber.
  - Add correlation_id to logs.
  - Add metrics endpoint or documented metrics hooks.
  - Add readiness/liveness behavior.
  - Add graceful shutdown to API and workers.
  - Add retry/backoff settings through config.
  - Add docs/security.md:
      no real secrets
      no real AWS calls in local
      localstack credentials only
      production IAM/IRSA/Pod Identity mapping
      signing/HSM/MPC out of scope for local
  - Add docs/operations.md.
  - Add runbooks listed above.
  - Add docs/production-readiness.md with:
      what is production-shaped
      what remains mocked
      what must change before real deployment
      AWS architecture mapping
      disaster recovery notes
      reconciliation-before-resume rule

Success criteria:
  - docs validate.
  - All major operational risks have runbooks or documented mitigations.
  - AGENT_TRACKER.md records evidence.

--------------------------------------------------------------------------------
GATE 13: CI/CD and Final Verification
--------------------------------------------------------------------------------

Objective:
  Ensure the repo can be validated consistently.

Tasks:
  - Create .github/workflows/ci.yml.
  - CI must include:
      cargo fmt --check
      cargo clippy --workspace --all-targets --all-features -- -D warnings
      cargo test --workspace --all-features
      spec validation
      SQL migration check
      frontend install/typecheck/test
      Docker build check where feasible
      docs validation
  - Add optional:
      cargo audit or cargo deny
      SBOM generation
      vulnerability scan
  - Add scripts/validate-all.sh.
  - make validate must run the local equivalent.
  - make test must run all practical tests.
  - make smoke must run full local happy path.
  - Update README.md with:
      architecture overview
      local quickstart
      services and ports
      test commands
      troubleshooting
      docs map
      ADR map
      production caveats
  - Update AGENT_TRACKER.md final verification section.

Success criteria:
  - make validate passes.
  - make test passes.
  - make dev-up + make smoke passes if Docker is available.
  - make k8s-smoke passes if Docker/kind are available.
  - Final response includes:
      what was built;
      what commands were run;
      what passed;
      what could not be run and why;
      local URLs;
      where the tracker, docs, specs, and ADRs live.

================================================================================
IMPLEMENTATION DETAILS AND REQUIREMENTS
================================================================================

Rust workspace:
  - Use stable Rust.
  - Use edition 2021 or 2024 if justified and supported.
  - Use Tokio.
  - Use Axum for API.
  - Use SQLx for Postgres.
  - Use serde and serde_json.
  - Use uuid.
  - Use chrono or time.
  - Use rust_decimal or justified fixed-point type.
  - Use thiserror for typed errors.
  - Use anyhow only at application boundaries.
  - Use tracing for logs.
  - Use aws-config, aws-sdk-sns, aws-sdk-sqs for messaging.
  - Configure AWS SDK endpoint URL for LocalStack.
  - No unwrap/expect in production paths unless justified and safe.

Domain:
  - SweepStatus must include:
      Created
      EligibilityChecked
      DisclosureChecked
      Approved
      CashLocked
      SubscriptionSubmitted
      TransferAgentConfirmed
      ChainMirrorObserved
      PositionBooked
      Reconciled
      Active
      RedemptionRequested
      SharesReserved
      RedemptionSubmitted
      RedemptionConfirmed
      CashCredited
      Settled
      ExceptionOpen
      ExceptionClosed
      Cancelled
  - SweepCommand must include:
      CheckEligibility
      CheckDisclosures
      Approve
      LockCash
      SubmitSubscription
      ConfirmTransferAgent
      ObserveChainMirror
      BookPosition
      Reconcile
      Activate
      RequestRedemption
      ReserveShares
      SubmitRedemption
      ConfirmRedemption
      CreditCash
      SettleRedemption
      OpenException
      CloseException
  - transition() must return a structured outcome:
      from_status
      to_status
      command
      emitted_events
      guard_results
  - Every invalid transition must be rejected.
  - Every transition must be auditable.
  - Direct DB status update outside command handler is forbidden by convention, docs, and tests where practical.

Persistence:
  - All command handling that changes state must be transactional.
  - Outbox event writes must be in the same DB transaction as business state changes.
  - Idempotency must be persisted.
  - Inbox deduplication must be persisted.
  - Unique constraints must guard external references.
  - Ledger entries must be append-only.
  - Do not update ledger entries in place except for metadata explicitly designed for processing state, if any.
  - Prefer new compensating entries over mutation.

Messaging:
  - LocalStack must emulate SNS/SQS.
  - Create one SNS topic and multiple SQS queues.
  - Use fanout.
  - Workers consume from SQS.
  - SQS message deletion only after successful processing.
  - Duplicate messages must be safe.
  - Retry with exponential backoff and jitter.
  - Poison messages must go to DLQ or be handled with documented local equivalent.
  - Message payloads must use event envelope.

API:
  - All writes require Idempotency-Key and Correlation-Id.
  - Responses must include correlation_id where useful.
  - Errors must use typed ErrorResponse.
  - API must expose /health and /ready.
  - API must expose Swagger/OpenAPI docs if feasible, or at least serve/open spec from repo.
  - API must not directly perform external side effects in request path.

Frontend:
  - Vite + React + TypeScript.
  - Show system status.
  - Show sweep order lifecycle timeline.
  - Support create sweep order.
  - Support duplicate-idempotency demonstration if feasible.
  - Show reconciliation breaks.
  - Show positions.
  - Clearly communicate local simulation boundaries.
  - Clearly communicate that FIDD balance itself does not earn yield.

Docker Compose:
  - Must be the simplest local entrypoint.
  - Postgres exposed on localhost.
  - API exposed on localhost:8080 unless conflict requires different port.
  - React exposed on localhost:5173 or localhost:3000.
  - LocalStack exposed on localhost:4566.
  - mock-transfer-agent exposed on a documented port.
  - Include healthchecks.

Kubernetes:
  - Local first with kind.
  - No real AWS dependency.
  - Include production-shaped manifests:
      resource requests/limits
      probes
      securityContext where practical
      ConfigMap
      Secret examples without real secrets
      ServiceAccounts
      NetworkPolicy
      PDB
      HPA/KEDA examples
  - Document how EKS would map to the same services.

Testing:
  - Unit tests for domain.
  - Property tests for invariants.
  - Integration tests with Postgres and LocalStack.
  - Contract/spec validation.
  - Frontend tests.
  - Smoke scripts.
  - E2E happy path.
  - E2E failure paths.
  - Tests must be runnable locally.

Security:
  - No real AWS calls in local.
  - No real secrets.
  - No private keys.
  - Local credentials must be dummy LocalStack credentials.
  - Add .env.example only.
  - Add .gitignore for .env, target, node_modules, coverage, generated secrets.
  - Document production IAM, KMS, Secrets Manager, HSM/MPC as architecture notes, not local implementation.

Observability:
  - Structured logs.
  - correlation_id propagation.
  - event_id propagation.
  - worker name in logs.
  - queue name in logs.
  - health/readiness.
  - document metrics.

Documentation:
  - README must be useful to a new engineer.
  - docs/index.md must be a docs entrypoint.
  - docs/architecture.md must include diagrams and service responsibilities.
  - docs/local-development.md must include exact local commands.
  - docs/testing.md must explain all test layers.
  - docs/production-readiness.md must distinguish local mocks from production needs.
  - docs/security.md must include local and production security posture.
  - docs/operations.md and runbooks must be actionable.
  - docs/traceability.md must connect source requirements to artifacts.

================================================================================
LOCAL COMMAND TARGETS
================================================================================

Implement these commands through Makefile and preferably justfile:

  make check-tools
  make bootstrap
  make validate-specs
  make validate-docs
  make validate
  make fmt
  make lint
  make test
  make dev-up
  make dev-down
  make dev-reset
  make smoke
  make smoke-failure-paths
  make docker-build
  make k8s-up
  make k8s-smoke
  make k8s-down

Expected behavior:

  make bootstrap
    Checks and installs reasonable local tools.
    Creates local env guidance.
    Does not require real AWS.

  make dev-up
    Starts docker compose stack.
    Runs migrations.
    Initializes LocalStack SNS/SQS resources.
    Starts API, workers, mock transfer agent, web.

  make smoke
    Creates a sweep order.
    Waits for Active.
    Verifies timeline and position.

  make smoke-failure-paths
    Verifies duplicate idempotency.
    Verifies duplicate confirmation safety.
    Verifies reconciliation break path.
    Verifies no-yield-on-FIDD invariant.

  make validate
    Runs spec validation, docs validation, Rust fmt/clippy/tests, frontend checks where available.

  make k8s-up
    Creates or uses kind cluster.
    Deploys local manifests.
    Initializes LocalStack inside cluster.
    Waits for readiness.

  make k8s-smoke
    Runs happy-path smoke through the local Kubernetes deployment.

================================================================================
ACCEPTANCE CRITERIA
================================================================================

The project is complete only when:

1. AGENT_TRACKER.md exists and is fully updated.
2. Source spec is preserved under spec/source/.
3. specs exist and validate:
   - OpenAPI
   - AsyncAPI
   - domain state machine YAML
   - JSON schemas
   - diagrams
   - TLA+ skeleton
4. ADRs exist and justify all major decisions.
5. Rust workspace compiles.
6. Domain tests pass.
7. Persistence tests pass.
8. Messaging tests pass or are covered by integration smoke tests.
9. API runs locally.
10. Workers run locally.
11. LocalStack SNS/SQS fanout works.
12. Postgres migrations apply.
13. React frontend runs locally.
14. Docker Compose full stack runs.
15. Happy-path smoke test passes.
16. Failure-path smoke tests pass.
17. Kubernetes manifests exist and validate.
18. kind local deployment works when local Docker/kind environment supports it.
19. CI workflow exists.
20. README and docs explain the system clearly.
21. No real AWS calls are required or made.
22. No secrets are committed.
23. No unresolved TODO/FIXME exists unless explicitly documented in AGENT_TRACKER.md as a deliberate deferral.
24. Final response reports exact status honestly.

================================================================================
FINAL RESPONSE FORMAT
================================================================================

When finished, respond with:

1. Summary of what was built.
2. Exact commands run and whether they passed.
3. Local run commands.
4. Local URLs and ports.
5. Test results.
6. Kubernetes status.
7. Docs/specs/ADR locations.
8. Any limitations or items deferred, with reasons.
9. Confirmation that AGENT_TRACKER.md is updated.

Do not claim success for commands you did not run.
Do not claim production readiness beyond the local production-shaped implementation.
Be explicit about mocks and simulation boundaries.