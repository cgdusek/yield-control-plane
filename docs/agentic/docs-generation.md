# Docs Generation

Documentation is validated by `scripts/validate-docs.sh`.

```bash
make validate-docs
```

The validator checks required documentation files, index links, runbook links, required command anchors, and banned unfinished-work markers. Documentation that describes an operational path must name the command or endpoint that enforces it.

