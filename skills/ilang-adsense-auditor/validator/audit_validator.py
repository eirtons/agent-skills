#!/usr/bin/env python3
"""AUDIT_JUDGE_v1 completeness gate.

The skill ships this validator as the structural guarantee that no requirement
gets skipped. It reads the requirement IDs straight out of references/
requirements.md, so the count follows that file when Google's policies change.

Usage:
    audit_validator.py --template            emit a skeleton report
    audit_validator.py --check report.json   validate a completed report
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DIMENSIONS = ("cmp", "evd", "cer", "imp", "fix")
VERDICTS = ("PASS", "BLOCKER", "HIGH", "MEDIUM", "UNKNOWN", "NA")
SITE_CONCLUSIONS = ("READY", "READY_AFTER_FIXES", "NOT_READY")

REQ_ID = re.compile(r"^\|\s*((?:OWN|CNT|POL|DIS|IMP)-\d{2})\s*\|")


def requirement_ids(refs: Path) -> list[str]:
    """Pull every requirement id from the markdown tables, in file order."""
    path = refs / "requirements.md"
    if not path.is_file():
        sys.exit(f"cannot find {path}")

    ids: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = REQ_ID.match(line.strip())
        if m and m.group(1) not in ids:
            ids.append(m.group(1))
    if not ids:
        sys.exit(f"no requirement ids found in {path}")
    return ids


def derive_site(verdicts: list[str]) -> str:
    """Barrier rule: a single BLOCKER vetoes, averages never override it."""
    if "BLOCKER" in verdicts:
        return "NOT_READY"
    if any(v in ("HIGH", "MEDIUM", "UNKNOWN") for v in verdicts):
        return "READY_AFTER_FIXES"
    return "READY"


def template(ids: list[str]) -> dict:
    return {
        "site": "",
        "audit_type": "",
        "site_conclusion": "",
        "judgments": [
            {
                "id": rid,
                "verdict": "",
                "v": dict.fromkeys(DIMENSIONS, 0.0),
                "issue": "",
                "evidence": "",
                "basis": "",
                "fix": "",
            }
            for rid in ids
        ],
    }


def check(report: dict, ids: list[str]) -> list[str]:
    errors: list[str] = []
    judgments = report.get("judgments")

    if not isinstance(judgments, list):
        return ["report has no 'judgments' list"]

    seen: dict[str, int] = {}
    for i, j in enumerate(judgments):
        where = f"judgments[{i}]"
        rid = j.get("id")

        if rid not in ids:
            errors.append(f"{where}: unknown requirement id {rid!r}")
            continue
        seen[rid] = seen.get(rid, 0) + 1

        verdict = j.get("verdict")
        if verdict not in VERDICTS:
            errors.append(f"{where} ({rid}): invalid verdict {verdict!r}")

        v = j.get("v")
        if not isinstance(v, dict):
            errors.append(f"{where} ({rid}): missing vector")
            continue
        for dim in DIMENSIONS:
            val = v.get(dim)
            if not isinstance(val, (int, float)) or isinstance(val, bool):
                errors.append(f"{where} ({rid}): {dim} is not a number")
            elif not 0.0 <= float(val) <= 1.0:
                errors.append(f"{where} ({rid}): {dim}={val} outside [0,1]")

        # prose fields; fix may be empty only when nothing needs fixing
        for field in ("issue", "evidence", "basis"):
            if not str(j.get(field, "")).strip():
                errors.append(f"{where} ({rid}): {field} is empty")
        if verdict not in ("PASS", "NA") and not str(j.get("fix", "")).strip():
            errors.append(f"{where} ({rid}): fix is empty but verdict is {verdict}")

        # verdict must agree with its own vector
        cmp_val = v.get("cmp")
        if isinstance(cmp_val, (int, float)) and not isinstance(cmp_val, bool):
            if verdict == "PASS" and float(cmp_val) < 0.5:
                errors.append(f"{where} ({rid}): PASS with cmp={cmp_val} (< 0.5)")
            if verdict == "BLOCKER" and float(cmp_val) > 0.5:
                errors.append(f"{where} ({rid}): BLOCKER with cmp={cmp_val} (> 0.5)")

    for rid in ids:
        n = seen.get(rid, 0)
        if n == 0:
            errors.append(f"requirement {rid} is not covered")
        elif n > 1:
            errors.append(f"requirement {rid} covered {n} times, expected once")

    declared = report.get("site_conclusion")
    if declared not in SITE_CONCLUSIONS:
        errors.append(f"site_conclusion {declared!r} is not a valid conclusion")
    else:
        expected = derive_site([j.get("verdict") for j in judgments])
        if declared != expected:
            errors.append(
                f"site_conclusion is {declared} but the judgments derive {expected}"
            )

    return errors


def main() -> int:
    ap = argparse.ArgumentParser(description="AUDIT_JUDGE_v1 completeness gate")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--template", action="store_true", help="emit a skeleton report")
    g.add_argument("--check", metavar="REPORT", help="validate a completed report")
    args = ap.parse_args()

    refs = Path(__file__).resolve().parent.parent / "references"
    ids = requirement_ids(refs)

    if args.template:
        json.dump(template(ids), sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    path = Path(args.check)
    if not path.is_file():
        print(f"no such report: {path}", file=sys.stderr)
        return 2
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"report is not valid JSON: {e}", file=sys.stderr)
        return 2

    errors = check(report, ids)
    if errors:
        print(f"FAIL — {len(errors)} problem(s), {len(ids)} requirements expected:")
        for e in errors:
            print(f"  - {e}")
        return 1

    counts: dict[str, int] = {}
    for j in report["judgments"]:
        counts[j["verdict"]] = counts.get(j["verdict"], 0) + 1
    summary = " ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    print(f"PASS — all {len(ids)} requirements covered exactly once")
    print(f"       verdicts: {summary}")
    print(f"       site_conclusion: {report['site_conclusion']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
