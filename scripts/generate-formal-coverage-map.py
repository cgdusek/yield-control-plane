#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml


DEFAULT_OUTPUT = Path("spec/refinement/formal_coverage_map.json")


SAFETY_AXIS_ACTIONS = {
    "tla_definition": "Add or repair the TLA+ invariant definition.",
    "tlaps_checked": "Add or repair the TLAPS theorem evidence and run make validate-tla.",
    "tlc_bounded": "Add the invariant or property to the bounded TLC config.",
    "rust_projection": "Map the Rust abstract state or transition to the TLA action.",
    "rust_tested": "Add Rust unit, property, trace, or integration test evidence.",
    "runtime_enforced": "Bind the invariant to a domain guard, SQL constraint, trigger, middleware, or worker policy.",
    "drift_checked": "Add the item to a validator that runs in make validate.",
}


LIVENESS_AXIS_ACTIONS = {
    "tla_temporal_property": "Add or repair the TLA+ temporal property.",
    "fairness_assumption": "Declare the fairness spec and explicit environment assumptions.",
    "tlaps_feasibility": "Classify TLAPS feasibility and cite supporting TLAPS safety theorems where temporal proof is not feasible.",
    "tlc_bounded_check": "Add the temporal property to a bounded TLC liveness config.",
    "rust_progress_test": "Add a Rust progress trace or property test for the path.",
    "runtime_progress_enforcement": "Bind the progress path to worker, retry, lease, or operator-resolution behavior.",
    "observable_or_smoke": "Add smoke, observable, or runbook evidence for the path.",
    "drift_checked": "Add the item to a validator that runs in make validate.",
}


def load_yaml(root: Path, relative: str) -> dict[str, Any]:
    path = root / relative
    if not path.exists():
        raise SystemExit(f"Missing coverage source: {relative}")
    loaded = yaml.safe_load(path.read_text()) or {}
    if not isinstance(loaded, dict):
        raise SystemExit(f"Coverage source must be a mapping: {relative}")
    return loaded


def percent(part: int, total: int) -> float:
    if total == 0:
        return 1.0
    return round(part / total, 4)


def score_axes(required: list[str], present: list[str]) -> tuple[float, list[str]]:
    present_set = set(present or [])
    missing = [axis for axis in required if axis not in present_set]
    return percent(len(required) - len(missing), len(required)), missing


def evidence_paths(records: list[dict[str, Any]]) -> list[str]:
    paths: list[str] = []
    for record in records or []:
        path = record.get("path")
        if isinstance(path, str) and path not in paths:
            paths.append(path)
    return paths


def closure_actions(missing_axes: list[str], action_catalog: dict[str, str]) -> list[str]:
    return [action_catalog.get(axis, f"Close missing axis: {axis}") for axis in missing_axes]


def build_safety_items(matrix: dict[str, Any]) -> list[dict[str, Any]]:
    required = list(matrix.get("required_axes") or [])
    items: list[dict[str, Any]] = []
    for raw in matrix.get("invariants") or []:
        axes = list(raw.get("axes") or [])
        coverage_score, missing_axes = score_axes(required, axes)
        status = raw.get("status")
        actions = closure_actions(missing_axes, SAFETY_AXIS_ACTIONS)
        if status != "covered":
            actions.append("Promote the invariant to covered or record a bounded deferral with validation impact.")
        closure_status = "closed" if status == "covered" and not missing_axes else "needs_work"
        item = {
            "id": raw.get("id"),
            "kind": "safety_invariant",
            "status": status,
            "closure_status": closure_status,
            "coverage_score": coverage_score,
            "required_axes": required,
            "present_axes": axes,
            "missing_axes": missing_axes,
            "closure_actions": actions,
            "evidence": {
                "tla_definition": raw.get("tla_definition"),
                "tlaps_theorems": list(raw.get("tlaps_theorems") or []),
                "tlc": raw.get("tlc") or {},
                "rust_tests": evidence_paths(raw.get("rust_tests") or []),
                "runtime_enforcement": evidence_paths(raw.get("runtime_enforcement") or []),
            },
        }
        items.append(item)
    return items


def assumption_actions(assumptions: list[str]) -> list[str]:
    return [
        f"To close unconditionally, discharge or operationally enforce liveness assumption: {assumption}"
        for assumption in assumptions
    ]


def build_liveness_items(matrix: dict[str, Any]) -> list[dict[str, Any]]:
    required = list(matrix.get("required_axes") or [])
    allowed_statuses = set((matrix.get("shared") or {}).get("allowed_statuses") or [])
    items: list[dict[str, Any]] = []
    for raw in matrix.get("properties") or []:
        axes = list(raw.get("axes") or [])
        coverage_score, missing_axes = score_axes(required, axes)
        status = raw.get("status")
        assumptions = list(raw.get("assumptions") or [])
        tlaps = raw.get("tlaps") or {}
        actions = closure_actions(missing_axes, LIVENESS_AXIS_ACTIONS)
        if status not in allowed_statuses:
            actions.append("Promote the property to an allowed liveness coverage status or record a bounded deferral.")
        if status == "conditional":
            actions.extend(assumption_actions(assumptions))
        if missing_axes or status not in allowed_statuses:
            closure_status = "needs_work"
        elif status == "bounded-pass":
            closure_status = "closed_bounded"
        else:
            closure_status = "closed_under_assumptions"
        item = {
            "id": raw.get("id"),
            "kind": "liveness_property",
            "status": status,
            "closure_status": closure_status,
            "coverage_score": coverage_score,
            "required_axes": required,
            "present_axes": axes,
            "missing_axes": missing_axes,
            "closure_actions": actions,
            "assumptions": assumptions,
            "evidence": {
                "tla_property": raw.get("tla_property"),
                "fairness": raw.get("fairness"),
                "tlc_config": raw.get("tlc_config"),
                "tlaps_temporal_property_feasible": tlaps.get("temporal_property_feasible"),
                "tlaps_property_theorems": list(tlaps.get("property_theorems") or []),
                "tlaps_supporting_safety_theorems": list(tlaps.get("supporting_safety_theorems") or []),
                "rust_tests": evidence_paths(raw.get("rust_tests") or []),
                "runtime_enforcement": evidence_paths(raw.get("runtime_enforcement") or []),
                "observability": evidence_paths(raw.get("observability") or []),
            },
        }
        items.append(item)
    return items


def build_refinement(mapping: dict[str, Any]) -> dict[str, Any]:
    commands = mapping.get("commands") or {}
    paths: list[dict[str, Any]] = []
    for command, record in commands.items():
        from_statuses = list(record.get("from") or [])
        for from_status in from_statuses:
            paths.append(
                {
                    "command": command,
                    "from": from_status,
                    "to": record.get("to"),
                    "tla_action": record.get("tla_action"),
                    "proof": record.get("proof"),
                    "closure_status": "closed",
                    "closure_actions": [],
                }
            )
    return {
        "boundary": mapping.get("boundary"),
        "creation_boundary": mapping.get("creation_boundary") or {},
        "command_count": len(commands),
        "transition_path_count": len(paths),
        "commands": [
            {
                "command": command,
                "tla_action": record.get("tla_action"),
                "from": list(record.get("from") or []),
                "to": record.get("to"),
                "proof": record.get("proof"),
                "closure_status": "closed",
            }
            for command, record in commands.items()
        ],
        "transition_paths": paths,
    }


def summarize(safety_items: list[dict[str, Any]], liveness_items: list[dict[str, Any]], refinement: dict[str, Any]) -> dict[str, Any]:
    safety_closed = sum(1 for item in safety_items if item["closure_status"] == "closed")
    liveness_bounded = sum(1 for item in liveness_items if item["closure_status"] == "closed_bounded")
    liveness_conditional = sum(1 for item in liveness_items if item["closure_status"] == "closed_under_assumptions")
    needs_work = [
        item["id"]
        for item in safety_items + liveness_items
        if item["closure_status"] == "needs_work"
    ]
    conditional_assumptions = sum(len(item.get("assumptions") or []) for item in liveness_items if item["closure_status"] == "closed_under_assumptions")
    unique_tlaps_theorems = {
        theorem
        for item in safety_items
        for theorem in item["evidence"].get("tlaps_theorems", [])
    } | {
        theorem
        for item in liveness_items
        for theorem in item["evidence"].get("tlaps_property_theorems", [])
    } | {
        theorem
        for item in liveness_items
        for theorem in item["evidence"].get("tlaps_supporting_safety_theorems", [])
    }
    return {
        "safety": {
            "total": len(safety_items),
            "closed": safety_closed,
            "needs_work": len(safety_items) - safety_closed,
            "closure_ratio": percent(safety_closed, len(safety_items)),
        },
        "liveness": {
            "total": len(liveness_items),
            "closed_bounded": liveness_bounded,
            "closed_under_assumptions": liveness_conditional,
            "needs_work": len([item for item in liveness_items if item["closure_status"] == "needs_work"]),
            "conditional_assumption_count": conditional_assumptions,
            "machine_checked_axis_ratio": percent(liveness_bounded + liveness_conditional, len(liveness_items)),
        },
        "rust_to_tla_refinement": {
            "command_count": refinement["command_count"],
            "transition_path_count": refinement["transition_path_count"],
            "closed_transition_path_count": len(refinement["transition_paths"]),
            "closure_ratio": percent(len(refinement["transition_paths"]), refinement["transition_path_count"]),
        },
        "tlaps": {
            "unique_theorem_references": len(unique_tlaps_theorems),
        },
        "closure": {
            "needs_work_count": len(needs_work),
            "needs_work_item_ids": needs_work,
            "absolute_liveness_open_assumption_count": conditional_assumptions,
        },
    }


def build_map(root: Path) -> dict[str, Any]:
    safety_matrix = load_yaml(root, "spec/refinement/invariant_coverage.yaml")
    liveness_matrix = load_yaml(root, "spec/refinement/liveness_coverage.yaml")
    rust_mapping = load_yaml(root, "spec/refinement/rust_tla_mapping.yaml")
    safety_items = build_safety_items(safety_matrix)
    liveness_items = build_liveness_items(liveness_matrix)
    refinement = build_refinement(rust_mapping)
    return {
        "version": 1,
        "artifact": "formal_coverage_map",
        "source_of_truth": [
            "spec/refinement/invariant_coverage.yaml",
            "spec/refinement/liveness_coverage.yaml",
            "spec/refinement/rust_tla_mapping.yaml",
        ],
        "closure_semantics": {
            "closed": "All required safety axes are present and validators bind the item to make validate.",
            "closed_bounded": "The liveness claim has explicit assumptions and bounded TLC/Rust/runtime evidence.",
            "closed_under_assumptions": "The liveness claim is covered only while its listed fairness and environment assumptions hold.",
            "needs_work": "At least one required axis, status, or closure condition is missing.",
        },
        "summary": summarize(safety_items, liveness_items, refinement),
        "safety": safety_items,
        "liveness": liveness_items,
        "rust_to_tla_refinement": refinement,
    }


def render(payload: dict[str, Any]) -> str:
    return json.dumps(payload, indent=2, sort_keys=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate or check the formal coverage JSON map.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="JSON output path")
    parser.add_argument("--check", action="store_true", help="Fail if the output file is missing or stale")
    args = parser.parse_args()

    root = Path.cwd()
    output = root / args.output
    rendered = render(build_map(root))

    if args.check:
        if not output.exists():
            raise SystemExit(f"Missing generated formal coverage map: {args.output}")
        existing = output.read_text()
        if existing != rendered:
            raise SystemExit(
                f"{args.output} is stale. Regenerate with ./scripts/generate-formal-coverage-map.py"
            )
        print("Formal coverage JSON map is current.")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered)
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
