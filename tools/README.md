# External DVFlow integration

The `./dv` launcher uses an external DVFlow checkout, normally the sibling
`TRNG-research/tools/dv` installation. Override `DVFLOW_ROOT` when it lives
elsewhere. DVFlow itself and the UVM library are not vendored in this repository;
`dvflow.json`, the manifests, and `tools/amba_ahb_dvflow_adapter/` describe the
project's files and simulator defaults.

The launcher defaults `CCACHE_DISABLE=1`, creates the local `sim/` output folder,
and requires Verilator 5.052 or newer for `sim` commands. Install a suitable
binary or select the existing local installation:

```sh
export PATH="$PWD/.toolchain/verilator-5.052/bin:$PATH"
./dv verify project --skip-source-check
./dv sim run --backend verilator --preflight-only
./dv sim run --backend verilator --test amba_ahb_lite_topology_test
./dv sim run --backend verilator --test amba_ahb_lite_active_smoke_test
```

`.toolchain/` is ignored and is not present in a fresh clone. Set
`DVFLOW_VERILATOR_BIN` when the launcher needs an explicit binary selection;
verify the generated build report to confirm which executable was used.

The UVM harness is `amba_ahb_lite_uvm_smoke`, selected by
`amba_ahb_lite_uvm.f`. Available test groups and current local results are in
[tb/README.md](../tb/README.md). `test_amba_ahb_lite_smoke` is not a registered
UVM test and must not be used.

The direct interface smoke can be linted separately:

```sh
verilator --lint-only --timing --Wall --Wno-fatal \
    --top-module amba_ahb_lite_if_smoke \
    src/amba_ahb_lite_if.sv tb/amba_ahb_lite_if_smoke.sv
```

Previous logs and reports contain the original workspace path. Preserve them
as historical evidence and generate new output for validation at the new path.
Record tool and dependency revisions, test selection, explicit seed, build/run
status, and UVM error/fatal counts. A successful process exit alone does not
establish a passing UVM test. No assertion, coverage, or other-simulator support
claim follows from a smoke run without its own evidence.

## Standalone regression

`run_regression.py` builds once and runs the 33-test behavioral suite. It requires
Verilator 5.052 or newer and a UVM source directory containing uvm_pkg.sv.

```sh
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --seeds 1 17 29 43 --waves
```

Use `--tests` for selected cases and `--output` for a separate artifact root.
The default is sim/regression. Source, UVM contents, tool version and build
command form the reuse fingerprint. Each run clears old case artifacts, records
its command and seed, and requires zero UVM errors/fatals plus a functional
report. Coverage.dat is code coverage input; functional.json contains sampled
counters. Review both against the protocol testplan before claiming closure.
