# Agent Working Agreement

Agents must implement the system as a runnable local platform, not a decorative scaffold. Every artifact must have an enforcement path: executable code, tests, validation scripts, CI checks, runtime scripts, Kubernetes/Docker usage, or an explicit tracker deferral.

## Required Behavior

- Read the tracker before acting.
- Update the tracker at every gate boundary and after every failed command.
- Keep source requirements traceable to code, tests, specs, docs, or an explicit deferral.
- Prefer small, enforceable artifacts over broad documents that are not used by any command or operational workflow.
- Replace unimplemented notes with working behavior before marking a gate passed.

## Forbidden Behavior

- Ornamental diagrams that are not referenced by docs or validation.
- Compiling code that has no runtime path or test value.
- Docs that only describe future intent.
- Status claims that are not supported by command output or code.
- Direct database status mutation outside command handlers.

## Practical Check

Before final handoff, run:

```bash
make validate
```

Then update [AGENT_TRACKER.md](../../AGENT_TRACKER.md) with the command evidence, any blockers, and the final verification status.
