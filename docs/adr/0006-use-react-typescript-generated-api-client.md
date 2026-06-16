# ADR-0006: Use React TypeScript with a Contract-Aligned API Client

## Status
Accepted

## Context
The operator console must remain aligned with the REST contract and distinguish simulation boundaries from financial claims.

## Decision
Use Vite, React, TypeScript, TanStack Query, and a handwritten API client kept aligned with `spec/openapi.yaml` through type tests and frontend checks.

## Options Considered
- Plain HTML and fetch
- React TypeScript with contract-aligned client
- Server-rendered UI

## Rationale
React TypeScript supports a richer local console while preserving type checks and testable UI states.

## Consequences
The frontend has a Node/pnpm dependency and a separate test surface.

## Validation
Validated by `pnpm --dir web/react-console typecheck`, lint, tests, and smoke workflows against the local API.
