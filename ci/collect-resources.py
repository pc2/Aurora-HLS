#!/usr/bin/env python3
"""Extract routed utilization for the AuroraFlow cores in collected bitstreams."""

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path


def core_resources(report):
    if set(report) != {"0"}:
        raise ValueError("expected one parsed report")
    report = report["0"]
    cores = []
    for unit in report["system diagram compute units"]:
        if not re.fullmatch(r"aurora_flow_[01]", unit["compute_unit"]):
            continue
        if unit["design_state"] != "routed":
            continue
        cores.append({
            "name": unit["compute_unit"],
            "resources": {key: float(unit[key])
                          for key in ("LUT", "REG", "BRAM", "DSP", "URAM")},
        })
    if sorted(core["name"] for core in cores) != ["aurora_flow_0", "aurora_flow_1"]:
        raise ValueError("expected both AuroraFlow core instances")
    return {"schema_version": 1, "design_state": "routed", "cores": cores}


def collect_resources(results_file):
    root = results_file.resolve().parent
    temporary_root = Path(__file__).resolve().parents[1] / "build-analysis" / "tmp"
    temporary_root.mkdir(parents=True, exist_ok=True)
    results = json.loads(results_file.read_text())["results"]
    for result in results:
        local = result.get("local") or {}
        if result["job_name"] != "hw-build" or local.get("kind") != "success":
            continue
        directory = (root / local["result_path"]).resolve()
        if root not in directory.parents:
            raise ValueError("result directory escapes collection")
        bitstreams = list(directory.glob("*.xclbin"))
        if len(bitstreams) != 1:
            raise ValueError("expected one hardware bitstream in " + str(directory))
        with tempfile.TemporaryDirectory(prefix="core-resources-", dir=temporary_root) as temporary:
            metadata = Path(temporary) / "system_diagram.json"
            subprocess.run([
                "xclbinutil", "--input", str(bitstreams[0]),
                "--dump-section", "SYSTEM_METADATA:RAW:" + str(metadata),
            ], check=True, stdout=subprocess.DEVNULL)
            report = Path(temporary) / "vitis-report.json"
            subprocess.run([
                "bash", str(Path(__file__).with_name("parse-vitis-report")),
                str(metadata), "-o", str(report),
            ], check=True, stdout=subprocess.DEVNULL)
            summary = core_resources(json.loads(report.read_text()))
            (directory / "vitis-report.json").write_text(report.read_text())
        (directory / "core-resources.json").write_text(json.dumps(summary, indent=2) + "\n")
        print("Collected routed core resources for " + result["combination_id"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results_file", type=Path)
    collect_resources(parser.parse_args().results_file)
