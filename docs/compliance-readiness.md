# Standards And Certification Readiness

Research date: 2026-06-18

This dossier maps the repository to US, EU, UK, global security, cloud, legal, regulatory, SOC, ISO, PCI, CSA, NIST, CIS, AWS, and production-adjacent readiness surfaces. It is an internal engineering readiness map only. It is not legal advice, regulatory advice, SOC attestation, ISO certification, PCI validation, external audit completion, production authorization, customer-data authorization, or transfer-agent authorization.

The source of truth is [standards_readiness_map.json](../spec/certification/standards_readiness_map.json). The local gate is:

```bash
make validate-standards-readiness
```

## Claim Boundaries

The matrix separates four questions that are often conflated:

| Question | Who Can Decide | Repo Role |
| --- | --- | --- |
| Internal engineering readiness | Engineering owners | Provide evidence, gaps, commands, and traceability. |
| External auditor readiness | Qualified auditor and control owner | Prepare evidence for future examination without claiming an examination occurred. |
| Legal or regulatory applicability | Counsel, compliance owner, regulator | Mark scope as conditional unless authoritative operator evidence exists. |
| Production deployment readiness | Production owner, security owner, business owner | Track gaps; do not treat local or AWS sandbox evidence as production authorization. |

## Readiness Categories

| Category | Rows | Current Stance |
| --- | --- | --- |
| External attestation | SOC 1, SOC 2, SOC 3 | Future external readiness only. |
| External certification | ISO 27001, 27017, 27018, 27701, 22301, 20000-1, PCI DSS | Future external or conditional; PCI DSS is outside current repo scope unless cardholder data enters scope. |
| Regulatory and legal | FTC GLBA Safeguards, SEC Regulation S-P, SEC Regulation SCI, FINRA, NYDFS Part 500, GDPR, DORA, FCA/PRA operational resilience | Conditional pending counsel and operator facts. |
| Control frameworks | NIST CSF 2.0, NIST SP 800-53 Rev. 5, CIS Controls v8.1 | Applicable as mapping aids and internal control structure. |
| Cloud assurance | AWS Well-Architected, AWS Financial Services Industry Lens, AWS shared responsibility, AWS Artifact, CSA CCM/CAIQ, CSA STAR | Applicable or conditional as cloud evidence and third-party assurance paths. |
| Production readiness | Internal production boundary | Future production workstream only. |

## Existing Evidence

The repo already has evidence that can support future readiness work:

- Formal safety and liveness artifacts: [formal verification](formal-verification.md), [liveness verification](liveness-verification.md), TLA+, TLAPS, TLC, and Kani-backed source proof gates.
- Runtime enforcement: Postgres uniqueness constraints, append-only ledger trigger, inbox/outbox tables, API metadata middleware, worker idempotency behavior, and FIDD yield-source rejection.
- Validation gates: `make validate`, `make validate-docs`, `make validate-aws-certification`, `make validate-repo-surface-coverage-map`, DB-backed tests, Compose smoke, and failure-path smoke.
- Cloud simulation evidence: [AWS simulation and internal certification](aws-certification.md) and the completed internal campaign report under `docs/certification/`.
- Operational boundaries: [security](security.md), [production readiness](production-readiness.md), and runbooks under [runbooks](runbooks/index.md).

## Main Gaps

The matrix intentionally records gaps as next actions rather than unresolved claims:

- External auditor scope, system description, control period, management assertion, evidence collection calendar, and sampling method are not present.
- Legal/regulatory applicability is not determined because the repo does not define the operating entity, licenses, customer data classes, jurisdictions, regulated activities, or external service-provider role.
- Privacy governance is not complete because the demo has no production data inventory, data subject workflow, cross-border transfer analysis, retention schedule, or data processing agreements.
- Production controls are not complete because authentication, authorization, production secrets, TLS, backup/restore, incident response, change management, vendor risk, BCP/DR, and monitoring ownership remain production work.
- Auditor-confidential materials such as AWS Artifact downloads must remain outside this public repo and be referenced by evidence manifest only.

## How To Use The Matrix

Use the JSON rows to decide what to close next:

1. Pick rows with `applicability` set to `applicable` or `future_external`.
2. Confirm `repo_evidence` paths and commands still exist.
3. Convert `missing_evidence` into owned work items.
4. Keep legal/regulatory rows conditional until counsel or a compliance owner records a scope decision.
5. Rerun the validator after any standards, source, or claim-boundary edit.

```bash
make validate-standards-readiness
make validate-docs
make validate
```

## Primary Source Set

Primary sources are recorded per row in the JSON matrix. The main source families are AICPA SOC resources, ISO standards pages, NIST CSF and SP 800-53, FTC Safeguards Rule, SEC Regulation S-P and Regulation SCI, FINRA cybersecurity checklist, NYDFS Part 500 resources, EUR-Lex GDPR and DORA texts, FCA operational resilience resources, PCI SSC PCI DSS resources, CIS Controls v8.1, CSA CCM/CAIQ and STAR, and AWS Well-Architected, AWS FSI Lens, AWS Artifact, shared responsibility, IAM, ECS, SQS, SNS, KMS, FIS, and CloudWatch guidance.
