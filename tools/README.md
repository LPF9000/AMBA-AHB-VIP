# DVFlow integration

The `./dv` launcher uses the shared DVFlow submodule at `tools/dv`, installed
in the root uv environment. Override `DVFLOW_ROOT` with another DVFlow checkout
when needed. The UVM library is an external pinned toolchain dependency;
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
./dv sim run --backend verilator --test amba_ahb_lite_active_smoke_test --seed 1
./dv sim run --backend verilator --test amba_ahb_lite_active_smoke_test --no-randomize --seed 1
./dv sim regression --backend verilator --seeds 1 17 29 43 --build-jobs 2
./dv sim regression --backend verilator --seed-count 20 --seed 29 --build-jobs 2
```

`.toolchain/` is ignored and is not present in a fresh clone. Set
`DVFLOW_VERILATOR_BIN` when the launcher needs an explicit binary selection;
verify the generated build report to confirm which executable was used.

Initialize the shared tool and Python dependencies with
`git submodule update --init --recursive` and `uv sync`. The root lockfile pins
DVFlow's Python dependencies and Z3; the launcher uses `.venv/bin/z3` and a
project-local uv cache. The initial UVM checkout is:

```sh
git clone https://github.com/accellera-official/uvm-core.git .toolchain/uvm-core
git -C .toolchain/uvm-core checkout --detach 78c06547a2a0a29b3dc9dcafae62b75b2ff61544
```

This is the official 2020.3.1 release. `dvflow.json` points to that local
checkout; no sibling research project is needed to resolve UVM or DVFlow.

The UVM harness is `tb`, selected by
`amba_ahb_lite_uvm.f`. Available test groups and current local results are in
[tb/README.md](../tb/README.md). `test_amba_ahb_lite_smoke` is not a registered
UVM test and must not be used.

The direct interface smoke can be linted separately:

```sh
verilator --lint-only --timing --Wall --Wno-fatal \
    --top-module amba_ahb_lite_if_smoke \
    -f amba_ahb_lite.f
```

Previous logs and reports contain the original workspace path. Preserve them
as historical evidence and generate new output for validation at the new path.
Record tool and dependency revisions, test selection, explicit seed, build/run
status, and UVM error/fatal counts. A successful process exit alone does not
establish a passing UVM test. No assertion, coverage, or other-simulator support
claim follows from a smoke run without its own evidence.

## Standalone regression

`run_regression.py` builds once per fingerprint and runs a selected suite:
33 functional, 3 isolated unit, or 5 independent slave integration tests. It requires
Verilator 5.052 or newer and a UVM source directory containing uvm_pkg.sv.

```sh
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --seeds 1 17 29 43 --waves
```

Use `--tests` for selected cases and `--output` for a separate artifact root.
The default is sim/regression. Source, UVM contents, tool version and build
command form the reuse fingerprint, including nested sequence and test files.
Each run clears old case artifacts, records
its command and seed, and requires zero UVM errors/fatals plus a functional
report. Coverage.dat is code coverage input; functional.json contains sampled
counters. Review both against the protocol testplan before claiming closure.

## Checks and runtime policy

`python3 tools/check_conventions.py` checks class/file/factory naming, include
ownership, compilation units, shared dimensions, indentation, callback cleanup
and selected test/sequence ownership boundaries. It is a bounded static check,
not a SystemVerilog parser or full UVM review. Its mutation tests run with
`python3 -m unittest tools.test_check_conventions`.

`python3 tools/run_assertions.py --verilator /path/to/verilator` runs legal,
disabled and deliberate-failure pin fixtures. A negative case must fail with
exactly its expected assertion ID, rather than any simulation failure.

The DVFlow checkout must provide `--randomize`/`--no-randomize` and
`--seed`. These options send the DVFLOW_RANDOMIZE plusarg and simulator seed;
Verilator builds enable `--assert`. Verilator random constraints require Z3 or
another supported solver. Set VERILATOR_SOLVER explicitly, or use the ignored
local solver path recognized by the launcher/runner. No solver is required for
`--no-randomize`. DVFlow source changes belong in its submodule repository.

The standalone runner also accepts `--verbosity`, default UVM_MEDIUM. Standard
UVM transaction tables are visible by default; UVM_LOW retains summaries. Its
`--uvm-ms-root` option requires the integration suite and the official external UVM-MS
package/includes; see [bridge notes](../tb/ms/README.md).

## Shared regressions and waveforms

The normal regression entry point is `./dv sim regression --backend verilator`.
The project adapter selects [regression.json](../manifests/regression.json), which
owns the test list and default seeds. Explicit `--tests` and `--seeds` override
the plan. `--seed-count` generates a recorded, reproducible seed list using
`--seed` as its generator seed. `--no-randomize` selects directed stimulus.
DVFlow reuses one build within the regression, checks simulator/UVM failures,
and writes separate logs for each test, seed and mode plus regression.json.
Ctrl+C preserves partial results and returns 130.

The submodule pins DVFlow v0.1.28 at
`a3fe106f2cd0ca78fbd4e7a6b7c28704bad65a24`. Its regression, randomization,
waveform and process-lifecycle changes are published in the
[stable release](https://github.com/LPF9000/dvflow/releases/tag/v0.1.28).
Run `git submodule update --init --recursive` and `uv sync --locked` after
updating this repository. The standalone runners provide focused component
and assertion fixtures; use `./dv` for normal functional regressions.

`./dv verify waveform` uses PyVCD for VCD parsing, GTKWave's converters for
VCD/FST interchange, and GTKWave or Surfer for viewing. PyVCD is managed in
DVFlow's uv dependencies; native viewers and converters are discovered through
the toolchain manifest. Signal choices and sessions belong to the project:

```sh
./dv verify waveform /path/to/waves.vcd --signals '*.bus.HCLK' '*.bus.HRESETn' \
    '*.bus.HADDR' '*.bus.HTRANS' --output sim/waveform_scan.json
./dv verify waveform /path/to/waves.vcd --action convert --output sim/waves.fst
./dv verify waveform sim/waves.fst --action open --viewer gtkwave
gtkwave sim/waves.fst --script tools/ahb_waveform.tcl
```

Inspection accepts VCD or FST, bounds selected events with `--max-events`, and
supports `--compare` for selected event comparisons. Hierarchy selections are
case-sensitive glob patterns. Reports retain declared widths, signal ranges,
X/Z values and event times in femtoseconds. This is a waveform utility, not an
AHB protocol checker. The reusable SVA and UVM components own protocol verdicts.
For an existing GTKWave session, use `--session /path/to/session.gtkw`.

The current language reference is [IEEE 1800-2023](https://standards.ieee.org/ieee/1800/7743/).
Practical tool references are [PyVCD](https://pyvcd.readthedocs.io/en/stable/vcd.reader.html),
[GTKWave formats](https://gtkwave.github.io/gtkwave/intro/formats.html), and
[Surfer](https://docs.surfer-project.org/book/).

## Continuous integration

The AHB workflow runs the native protocol fixtures, the 33-test/four-seed
functional plan and the three component-unit tests with pinned Verilator and
Accellera UVM revisions. It fetches the public checker submodule and uses the
standalone runners. Solver installation uses the version and wheel hashes from
the root lock, recorded in `tools/ci/requirements.txt`.

DVFlow is a private dependency and requires repository read access for recursive
checkout and the normal `./dv` environment. Its own release CI qualifies the
shared tool. Project adapter/preflight and `./dv` integration are exercised in
the authorized local environment; the public native-source workflow requires
no private dependency credential. Add independent shared-tool integration CI
when an appropriately scoped read credential is configured.

The checker dependency is pinned to
`5d0edc2fc5ce292ac4d2a24447563667fdf754da` on its reviewed feature branch.
Its [draft PR](https://github.com/LPF9000/sva-checkers/pull/1) tracks initial
qualification; four-state, formal and alternate-simulator gates remain open.
