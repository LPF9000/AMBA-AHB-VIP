#!/usr/bin/env python3
"""Check AHB VIP class layout, package ownership, and selected UVM boundaries."""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re
import sys


def check(repo: Path) -> list[str]:
    failures: list[str] = []
    sources = sorted([*(repo / "src").rglob("*.sv*"), *(repo / "tb").rglob("*.sv*")])
    texts = {path: path.read_text() for path in sources}
    included: Counter[Path] = Counter()
    classes: dict[str, Path] = {}

    def report(path: Path, message: str) -> None:
        failures.append(f"{path.relative_to(repo)}: {message}")

    for path, text in texts.items():
        code = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
        declarations = re.findall(r"^(virtual\s+)?class\s+(\w+)", code, re.M)
        if declarations:
            if len(declarations) != 1 or declarations[0][1] != path.stem:
                report(path, "keep one class per file, with a matching file name")
            for abstract, name in declarations:
                if name in classes:
                    report(path, f"duplicate class {name}")
                classes[name] = path
                if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
                    report(path, "class name must use lower_snake_case")
                if name.endswith(("_config", "_sequence")):
                    report(path, "use _cfg and _seq suffixes")
                is_ms_proxy = bool(re.search(r"extends\s+amba_ahb_lite_ms_proxy\b", code))
                if not abstract and not is_ms_proxy and not re.search(
                    rf"`uvm_(?:object|component)(?:_param)?_utils(?:_begin)?\s*\(\s*{name}\b", code
                ):
                    report(path, "concrete class needs factory registration")
                if not re.search(rf'function\s+new\s*\(\s*string\s+name\s*=\s*"{name}"', code):
                    report(path, "constructor default name must match the class")
        timeunit = re.search(r"\btimeunit\b", code)
        first_import = re.search(r"\bimport\b", code)
        if timeunit and first_import and first_import.start() < timeunit.start():
            report(path, "timeunit/timeprecision declarations must precede imports in the scope")
        if re.search(r"\b(?:logic|bit)\s*\[31\s*:\s*0\]", code):
            report(path, "use shared address/data typedefs instead of a fixed-width declaration")
        if re.search(r"\b32'[hbd]", code, re.I):
            report(path, "use typed, named protocol definitions or test fixtures")
        for number, line in enumerate(text.splitlines(), start=1):
            indentation = len(line) - len(line.lstrip(" "))
            if line.strip() and (line.startswith("\t") or indentation % 4):
                report(path, f"line {number}: indentation must use four-space steps")
        is_sequence = path.parent.name == "seq_lib" and bool(declarations)
        is_test = path.parent.name == "tests" and bool(declarations)
        if is_sequence or is_test:
            if re.search(r"\b(?:vif|ctrl|bus)\s*\.", code):
                report(path, "tests/sequences must not access pins or interfaces")
            if re.search(r"@\s*\(|#\s*\d", code):
                report(path, "put signal waits and time delays in timing components")
        if is_sequence and "uvm_config_db" in code:
            report(path, "sequence cfg must come through typed sequencer/explicit context")
        if not is_test and re.search(r"\.(?:raise|drop)_objection\s*\(", code):
            report(path, "test owns phase objections")
        for phase, body in re.findall(
            r"function\s+void\s+((?:build|connect|check|report|final)_phase)\s*\([^)]*\);(.*?)endfunction",
            code, re.S
        ):
            if f"super.{phase}(phase)" not in body:
                report(path, f"{phase} must call the inherited phase implementation")
        if "uvm_report_cb::add(null" in code and "uvm_report_cb::delete(null" not in code:
            report(path, "component must remove its global report callback in final_phase")
        for name in re.findall(r'`include\s+"([^"]+)"', code):
            if name in {"uvm_macros.svh", "uvm_ms_includes.svh"}:
                continue
            root = repo / ("src" if path.is_relative_to(repo / "src") else "tb")
            target = root / name
            if target in texts:
                included[target] += 1
            elif not (repo / "checkers/src" / name).is_file():
                report(path, f"include does not resolve: {name}")

    for name, path in classes.items():
        if included[path] != 1:
            report(path, f"class must have one package include owner; found {included[path]}")
        if name.endswith("_seq") and path.parent.name != "seq_lib":
            report(path, "sequence belongs in seq_lib")
        if name.endswith("_test") and path.parent.name != "tests":
            report(path, "test belongs in tests")

    for filelist in sorted(repo.glob("amba_ahb_lite*.f")):
        compiled = [repo / line.strip() for line in filelist.read_text().splitlines()
                    if line.strip() and not line.startswith(("+", "//"))]
        for path in compiled:
            if not path.is_file():
                report(filelist, f"missing compilation unit: {path.relative_to(repo)}")
            if included[path]:
                report(filelist, f"included source also compiled independently: {path.relative_to(repo)}")
        if len(compiled) != len(set(compiled)):
            report(filelist, "duplicate compilation unit")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    failures = check(args.repo.resolve())
    for failure in failures:
        print(failure)
    if failures:
        print(f"FAIL: {len(failures)} convention violations")
        return 1
    print("PASS: class/file/factory names, include ownership, shared types, indentation and UVM boundaries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
