#!/usr/bin/env python3
"""Run independent positive and deliberate-failure AHB-Lite SVA fixtures."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import signal
import subprocess
import time


REPO = Path(__file__).resolve().parents[1]
BUILD_TIMEOUT = 180
CASE_TIMEOUT = 30
ASSERTION_RE = re.compile(r"Assertion failed[^\n]*?:\s*([A-Za-z_][A-Za-z0-9_]*)\b")
CASES = {
    "legal": None,
    "disabled": None,
    "reset_idle": "AHB_ASSERT_RESET_IDLE",
    "reset_ready": "AHB_ASSERT_RESET_READY",
    "alignment": "AHB_ASSERT_ALIGNMENT",
    "size": "AHB_ASSERT_SIZE",
    "wait_address": "AHB_ASSERT_WAIT_ADDRESS",
    "wait_write": "AHB_ASSERT_WAIT_WRITE_DATA",
    "error_first": "AHB_ASSERT_ERROR_FIRST",
    "error_second": "AHB_ASSERT_ERROR_SECOND",
    "nontransfer": "AHB_ASSERT_NONTRANSFER",
    "byte_inactive": None,
    "byte_active": "AHB_ASSERT_WAIT_WRITE_DATA",
    "wait_idle_change": None,
    "route": "AHB_ASSERT_RESPONSE_ROUTE",
    "seq_without_burst": "AHB_ASSERT_BURST_STATE",
    "busy_after_single": "AHB_ASSERT_BURST_STATE",
    "start_boundary": "AHB_ASSERT_BURST_START_BOUNDARY",
    "burst_address": "AHB_ASSERT_BURST_ADDRESS",
    "burst_control": "AHB_ASSERT_BURST_CONTROL",
    "early_end": "AHB_ASSERT_BURST_EARLY_END",
    "wrap4": None,
    "incr4": None,
    "busy_wait": None,
    "wait_type": "AHB_ASSERT_WAIT_TYPE",
    "error_cancel": None,
}


def input_hashes() -> dict[str, str]:
    inputs = [
        *REPO.joinpath("src").rglob("*.sv"),
        *REPO.joinpath("src").rglob("*.svh"),
        *REPO.joinpath("checkers/src").rglob("*.sv"),
        *REPO.joinpath("checkers/src").rglob("*.svh"),
        REPO / "tb" / "amba_ahb_lite_tb_params_pkg.sv",
        REPO / "tb" / "amba_ahb_lite_assert_smoke.sv",
    ]
    return {
        str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(set(inputs))
        if path.is_file()
    }


def kill_process_group(process: subprocess.Popen[str]) -> None:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def run_command(command: list[str], cwd: Path, environment: dict[str, str],
                timeout: float, log_path: Path) -> dict[str, object]:
    with log_path.open("w") as log:
        try:
            process = subprocess.Popen(
                command,
                cwd=cwd,
                env=environment,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
                text=True,
            )
        except FileNotFoundError as error:
            log.write(f"Unable to start command: {error}\n")
            return {"returncode": 127, "timed_out": False}
        except OSError as error:
            log.write(f"Unable to start command: {error}\n")
            return {"returncode": 126, "timed_out": False}
        try:
            return {"returncode": process.wait(timeout=timeout), "timed_out": False}
        except subprocess.TimeoutExpired:
            kill_process_group(process)
            log.write(f"Command timed out after {timeout:g} seconds.\n")
            return {"returncode": 124, "timed_out": True}
        except KeyboardInterrupt:
            kill_process_group(process)
            raise


def write_summary(output: Path, summary: dict[str, object]) -> None:
    (output / "summary.json").write_text(json.dumps(summary, indent=4) + "\n")


def interrupt_handler(signum: int, frame: object) -> None:
    del signum, frame
    raise KeyboardInterrupt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--output", type=Path, default=Path("sim/assertion_validation"))
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    signal.signal(signal.SIGTERM, interrupt_handler)

    output = args.output.resolve()
    try:
        output.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        parser.error(f"output directory already exists: {output}")
    (output / "obj_dir").mkdir()

    tool = shutil.which(args.verilator)
    source_hashes = input_hashes()
    environment = os.environ.copy()
    environment["CCACHE_DISABLE"] = "1"
    summary: dict[str, object] = {
        "seed": 1,
        "tool": tool,
        "tool_revision": "unavailable",
        "source_hashes": source_hashes,
        "build_command": [],
        "build_returncode": None,
        "tests": [],
        "passed": 0,
        "total": len(CASES),
        "interrupted": False,
        "limits": ["Known-control X/Z assertion remains unqualified under two-state Verilator"],
    }
    records: list[dict[str, object]] = []
    summary["tests"] = records
    interrupted = False

    try:
        if tool is None:
            summary["tool_error"] = f"Verilator executable not found: {args.verilator}"
            summary["build_returncode"] = 127
            summary["tests"] = [
                {"case": name, "expected": expected, "status": "not run: Verilator unavailable",
                 "pass": False}
                for name, expected in CASES.items()
            ]
            write_summary(output, summary)
            print("Verilator executable not found; see", output / "summary.json")
            return 127

        tool_version = run_command([tool, "--version"], REPO, environment, 10,
                                   output / "version.log")
        version_text = (output / "version.log").read_text().strip()
        summary["tool"] = tool
        summary["tool_revision"] = version_text or f"version command exited {tool_version['returncode']}"
        if tool_version["returncode"] != 0:
            summary["tool_error"] = version_text
            summary["build_returncode"] = int(tool_version["returncode"])
            write_summary(output, summary)
            print("Unable to identify Verilator revision; see", output / "version.log")
            return int(tool_version["returncode"])

        build_command = [
            tool,
            "--binary",
            "--timing",
            "--assert",
            "--timescale",
            "1ns/1ps",
            "-Wno-fatal",
            "--top-module",
            "amba_ahb_lite_assert_smoke",
            "-Isrc",
            "-Icheckers/src",
            "--Mdir",
            str(output / "obj_dir"),
            "--build-jobs",
            "2",
            "src/amba_ahb_params_pkg.sv",
            "src/amba_ahb_lite_assert.sv",
            "tb/amba_ahb_lite_tb_params_pkg.sv",
            "tb/amba_ahb_lite_assert_smoke.sv",
        ]
        summary["build_command"] = build_command
        build_result = run_command(build_command, REPO, environment, BUILD_TIMEOUT,
                                   output / "build.log")
        summary["build_returncode"] = build_result["returncode"]
        summary["build_timed_out"] = build_result["timed_out"]
        if build_result["returncode"] != 0:
            summary["tests"] = [
                {"case": name, "expected": expected, "status": "not run: build failed", "pass": False}
                for name, expected in CASES.items()
            ]
            write_summary(output, summary)
            print("Assertion build failed; see", output / "build.log")
            return int(build_result["returncode"])

        binary = output / "obj_dir" / "Vamba_ahb_lite_assert_smoke"
        for name, expected in CASES.items():
            run_command_line = [str(binary), "+verilator+seed+1", f"+AHB_ASSERT_CASE={name}"]
            case_log = output / f"{name}.log"
            try:
                result = run_command(run_command_line, output, environment, CASE_TIMEOUT, case_log)
            except KeyboardInterrupt:
                records.append({"case": name, "expected": expected, "status": "interrupted",
                                "returncode": 130, "pass": False, "command": run_command_line})
                raise
            content = case_log.read_text()
            diagnostics = ASSERTION_RE.findall(content)
            if expected is None:
                passed = (result["returncode"] == 0
                          and f"AHB_ASSERT_SMOKE PASS {name}" in content
                          and not diagnostics)
            else:
                passed = result["returncode"] not in (0, 124, 126, 127) and diagnostics == [expected]
            records.append({
                "case": name,
                "expected": expected,
                "diagnostics": diagnostics,
                "returncode": result["returncode"],
                "timed_out": result["timed_out"],
                "pass": passed,
                "command": run_command_line,
            })
            summary["passed"] = sum(bool(record["pass"]) for record in records)
            write_summary(output, summary)
            print(f"{'PASS' if passed else 'FAIL'} {name}: {diagnostics}", flush=True)
    except KeyboardInterrupt:
        interrupted = True
        summary["interrupted"] = True
        summary["interrupted_at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        for name, expected in list(CASES.items())[len(records):]:
            records.append({"case": name, "expected": expected,
                            "status": "not run: interrupted", "pass": False})
        summary["passed"] = sum(bool(record.get("pass")) for record in records)
        write_summary(output, summary)
        print("Assertion validation interrupted; partial report:", output / "summary.json")
        return 130
    finally:
        summary["interrupted"] = bool(summary.get("interrupted", False) or interrupted)
        summary["passed"] = sum(bool(record.get("pass")) for record in records)
        write_summary(output, summary)

    print(f"Result {summary['passed']}/{summary['total']}; evidence: {output}", flush=True)
    return 0 if summary["passed"] == summary["total"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
