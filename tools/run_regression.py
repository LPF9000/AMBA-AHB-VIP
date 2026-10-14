#!/usr/bin/env python3
"""Build once and run the local AMBA 3 AHB-Lite verification suite."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

PLAN = json.loads((Path(__file__).resolve().parents[1] / "manifests/regression.json").read_text())
TESTS = tuple(name.removeprefix("amba_ahb_lite_") for name in PLAN["tests"])
INTEGRATION_TESTS = tuple(name.removeprefix("amba_ahb_lite_") for name in PLAN["integration_tests"])
UNIT_TESTS = tuple(name.removeprefix("amba_ahb_lite_") for name in PLAN["unit_tests"])


def revision(path: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else "unversioned"


def fingerprint(repo: Path, command: list[str], version: str, uvm_root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted([*(repo / "src").rglob("*.sv*"), *(repo / "tb").rglob("*.sv*"),
                        *(repo / "checkers/src").rglob("*.sv*"),
                        *repo.glob("amba_ahb_lite*.f")]):
        digest.update(str(path.relative_to(repo)).encode())
        digest.update(path.read_bytes())
    for path in sorted(uvm_root.rglob("*.sv*")):
        digest.update(str(path.relative_to(uvm_root)).encode())
        digest.update(path.read_bytes())
    digest.update(json.dumps(command).encode())
    digest.update(version.encode())
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verilator", default=os.environ.get("DVFLOW_VERILATOR_BIN", "verilator"))
    parser.add_argument("--uvm-root", type=Path, default=Path(os.environ.get(
        "UVM_ROOT", str(Path(__file__).resolve().parents[1] / ".toolchain/uvm-core/src"))))
    parser.add_argument("--uvm-ms-root", type=Path, help="external UVM-MS 1.0 package directory (integration suite only)")
    parser.add_argument("--output", type=Path, default=Path("sim/regression"))
    parser.add_argument("--tests", nargs="+", choices=TESTS + UNIT_TESTS, default=None)
    parser.add_argument("--suite", choices=("functional", "unit", "integration"), default="functional")
    parser.add_argument("--randomize", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--seeds", nargs="+", type=int, default=[1])
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--verbosity", choices=("UVM_NONE", "UVM_LOW", "UVM_MEDIUM", "UVM_HIGH", "UVM_FULL", "UVM_DEBUG"), default="UVM_MEDIUM")
    parser.add_argument("--waves", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    args = parser.parse_args()
    if args.jobs < 1 or any(seed < 1 for seed in args.seeds):
        parser.error("jobs and seeds must be positive")
    selected = {"functional": TESTS, "unit": UNIT_TESTS, "integration": INTEGRATION_TESTS}[args.suite]
    args.tests = list(selected) if args.tests is None else args.tests
    if any(test not in selected for test in args.tests):
        parser.error("selected tests do not belong to the requested suite")
    repo = Path(__file__).resolve().parents[1]
    conventions = subprocess.run([sys.executable, str(repo / "tools/check_conventions.py")],
                                 cwd=repo, check=False)
    if conventions.returncode:
        return conventions.returncode
    tool = shutil.which(args.verilator)
    if tool is None:
        parser.error("Verilator executable not found")
    uvm = args.uvm_root.resolve()
    if not (uvm / "uvm_pkg.sv").is_file():
        parser.error("--uvm-root must name the directory containing uvm_pkg.sv")
    version = subprocess.check_output([tool, "--version"], text=True).strip()
    match = re.search(r"Verilator (\d+)\.(\d+)", version)
    if match is None or tuple(map(int, match.groups())) < (5, 52):
        parser.error("Verilator 5.052 or newer is required")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    top = {"functional": "tb", "unit": "amba_ahb_lite_unit_top", "integration": "tb"}[args.suite]
    filelist = {"functional": "amba_ahb_lite_uvm.f", "unit": "amba_ahb_lite_unit.f", "integration": "amba_ahb_lite_uvm.f"}[args.suite]
    command = [tool, "--binary", "--timing", "--trace", "--coverage", "--assert", "-Wno-fatal",
               "-sv", "--timescale", "1ns/1ps", "--top-module", top, "-Mdir", str(output / "obj_dir"),
               "--build-jobs", str(args.jobs), "+define+UVM_NO_DPI", f"+incdir+{uvm}",
               str(uvm / "uvm_pkg.sv"), "-f", filelist, "-o", "Vtb"]
    if args.suite == "integration":
        command.append("-Guse_simple_slave=1")
    if args.uvm_ms_root:
        ms_root = args.uvm_ms_root.resolve()
        if args.suite != "integration" or not (ms_root / "uvm_ms_pkg.sv").is_file():
            parser.error("--uvm-ms-root requires the integration suite and the standard uvm_ms_pkg.sv")
        insertion = command.index("-f")
        command[insertion:insertion] = ["+define+AHB_UVM_MS", f"+incdir+{ms_root}", str(ms_root / "uvm_ms_pkg.sv")]
    signature = fingerprint(repo, command, version, uvm)
    if args.uvm_ms_root:
        external = hashlib.sha256()
        for path in sorted(ms_root.glob("*.sv*")):
            external.update(path.read_bytes())
        signature = hashlib.sha256((signature + external.hexdigest()).encode()).hexdigest()
    manifest = output / "build.json"
    binary = output / "obj_dir/Vtb"
    reuse = manifest.is_file() and binary.is_file() and json.loads(manifest.read_text()).get("fingerprint") == signature
    environment = os.environ.copy()
    environment["CCACHE_DISABLE"] = "1"
    solver = repo / ".venv/bin/z3"
    if solver.is_file() and "VERILATOR_SOLVER" not in environment:
        environment["VERILATOR_SOLVER"] = f"{solver} -in -smt2"
    if not reuse:
        print("Building AHB-Lite suite; see", output / "build.log", flush=True)
        with (output / "build.log").open("w") as log:
            build = subprocess.run(command, cwd=repo, env=environment,
                                   stdout=log, stderr=subprocess.STDOUT, check=False)
        if build.returncode:
            print("Build failed:", build.returncode, flush=True)
            return build.returncode
        manifest.write_text(json.dumps({"fingerprint": signature, "command": command,
                            "version": version, "uvm_revision": revision(uvm)}, indent=4) + "\n")
    if args.build_only:
        return 0
    results = []
    aggregate: dict[str, object] = {}
    for seed in args.seeds:
        for suffix in args.tests:
            test = "amba_ahb_lite_" + suffix
            mode = "randomized" if args.randomize else "directed"
            case = output / f"{suffix}_seed_{seed}_{mode}_{args.verbosity.lower()}"
            case.mkdir(exist_ok=True)
            coverage = case / "functional.json"
            for artifact in (coverage, case / "coverage.dat", case / "waves.vcd"):
                if artifact.exists():
                    artifact.unlink()
            run_command = [str(binary), f"+UVM_TESTNAME={test}", f"+verilator+seed+{seed}",
                           f"+AHB_COVERAGE_FILE={coverage}", f"+DVFLOW_RANDOMIZE={int(args.randomize)}", f"+UVM_VERBOSITY={args.verbosity}"]
            if args.waves:
                run_command.append(f"+AHB_WAVES={case / 'waves.vcd'}")
            try:
                with (case / "run.log").open("w") as log:
                    run = subprocess.run(run_command, cwd=case, env=environment,
                                         stdout=log, stderr=subprocess.STDOUT, timeout=60, check=False)
                rc = run.returncode
            except subprocess.TimeoutExpired:
                rc = 124
            content = (case / "run.log").read_text()
            errors = re.findall(r"UVM_ERROR\s*:\s*(\d+)", content)
            fatals = re.findall(r"UVM_FATAL\s*:\s*(\d+)", content)
            error_count = int(errors[-1]) if errors else None
            fatal_count = int(fatals[-1]) if fatals else None
            passed = rc == 0 and error_count == 0 and fatal_count == 0 and (args.suite == "unit" or coverage.is_file())
            record = {"suite": args.suite, "randomize": args.randomize, "verbosity": args.verbosity, "test": test, "seed": seed, "returncode": rc, "errors": error_count,
                      "fatals": fatal_count, "pass": passed, "command": run_command,
                      "log": str(case / "run.log"), "coverage": str(coverage)}
            (case / "report.json").write_text(json.dumps(record, indent=4) + "\n")
            results.append(record)
            print(f"{'PASS' if passed else 'FAIL'} {test} seed={seed} errors={error_count} fatals={fatal_count}", flush=True)
            if coverage.is_file():
                counts = json.loads(coverage.read_text())
                for key, value in counts.items():
                    if isinstance(value, list):
                        if value and isinstance(value[0], list):
                            previous = aggregate.setdefault(key, [[0] * len(row) for row in value])
                            for i, row in enumerate(value):
                                for j, number in enumerate(row):
                                    previous[i][j] += number
                        else:
                            previous = aggregate.setdefault(key, [0] * len(value))
                            for i, number in enumerate(value):
                                previous[i] += number
                    else:
                        aggregate[key] = aggregate.get(key, 0) + value
    summary = {"uvm_ms_digital_view": bool(args.uvm_ms_root), "suite": args.suite, "randomize": args.randomize, "verilator": version, "uvm_revision": revision(uvm), "source_fingerprint": signature,
               "build_reused": reuse, "tests": results, "functional_counts": aggregate,
               "passed": sum(item["pass"] for item in results), "total": len(results),
               "limits": ["Behavioral endpoints only; no user DUT/IP integration",
                          "Verilator does not establish four-state X/Z validation",
                          "No alternate simulator portability result"]}
    (output / "summary.json").write_text(json.dumps(summary, indent=4) + "\n")
    print(f"Result: {summary['passed']}/{summary['total']} passed", flush=True)
    return 0 if summary["passed"] == summary["total"] else 1


if __name__ == "__main__":
    sys.exit(main())
