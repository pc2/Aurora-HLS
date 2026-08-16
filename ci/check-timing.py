#!/usr/bin/env python3
"""Fail a hardware build if its implementation timing report has negative WNS."""

import json
import os
import re
from pathlib import Path


def report_wns(path: Path) -> float:
    lines = path.read_text(errors="replace").splitlines()
    for index, line in enumerate(lines):
        if "WNS(ns)" not in line:
            continue
        for candidate in lines[index + 1:index + 8]:
            match = re.match(r"\s*([+-]?\d+(?:\.\d+)?)\s+", candidate)
            if match:
                return float(match.group(1))
    raise RuntimeError(f"could not find WNS in {path}")


reports = sorted(Path("timing-reports").glob("*.rpt"))
if not reports:
    raise SystemExit("no timing reports found")

results = [{"path": str(path), "wns_ns": report_wns(path)} for path in reports]
summary = {
    "target_clock_hz": int(os.environ["TARGET_CLOCK_HZ"]),
    "width_bytes": int(os.environ["WIDTH"]),
    "framing": int(os.environ["FRAMING"]),
    "reports": results,
}
Path("timing.json").write_text(json.dumps(summary, indent=2) + "\n")

worst = min(result["wns_ns"] for result in results)
print(f"implementation timing: worst WNS {worst:.3f} ns across {len(results)} report(s)")
if worst < 0.0:
    raise SystemExit(f"timing failed: worst WNS is {worst:.3f} ns")
