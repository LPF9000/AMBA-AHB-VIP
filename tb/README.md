# AHB-Lite verification harnesses

The current profile is ARM IHI 0033A AMBA 3 AHB-Lite, 32-bit addresses/data,
little-endian payloads, one master and one selected slave. Runtime configuration
rejects other widths/profiles. The harnesses exercise this slice without user IP.

| Suite | Filelist / top | Purpose |
| --- | --- | --- |
| functional | amba_ahb_lite_uvm.f / tb | 35 scenario tests with independent behavioral timing fixtures and supplemental VIP-to-VIP cases |
| unit | amba_ahb_lite_unit.f / amba_ahb_lite_unit_top | 3 isolated diagnostic, copy and configuration tests; no bus traffic or physical top |
| integration | amba_ahb_lite_uvm.f / tb (use_simple_slave=1) | 5 functional tests with the temporary module memory slave |

Tests own configuration and objections. The environment invokes initial-reset
lifecycle methods in pre_reset/reset; the test prepares a concrete virtual sequence
in pre_main, then starts it in run. Driver, monitor and mid-test reset services
remain in run. The typed virtual sequencer supplies master `m_sqr`, slave and batch
handles. Sequences coordinate children using explicit parent handles, without pins,
scoreboard verdicts or configuration-database lookups.

Use the released DVFlow tool for the functional suite:

```sh
./dv sim regression --backend verilator --seeds 1 17 29 43 --build-jobs 2
```

The focused runner also selects the isolated unit and temporary-slave suites.
Run with an external UVM source directory and Verilator 5.052 or newer:

```sh
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --seeds 1 17 29 43
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --suite unit --output sim/unit
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --suite integration --output sim/dut
```

Use separate output directories for distinct suites/build options. `--tests`
selects tests belonging to that suite. Randomization defaults on: virtual-sequence
payloads vary, directed controls stay fixed, and random scenarios randomize legal
items. Verilator constraints require a solver, selected with `VERILATOR_SOLVER`
(e.g. `/path/to/z3 -in -smt2`). The runner also recognizes the project environment's
`.venv/bin/z3`. `--no-randomize` keeps deterministic fixtures
and sends `+DVFLOW_RANDOMIZE=0`. Reports record mode, seed, command and UVM counts.

Every completed/aborted monitor transaction and expected/actual scoreboard
transaction prints using `do_print` and `uvm_table_printer` at UVM_MEDIUM. Use
`--verbosity UVM_LOW` to hide transaction tables while retaining summaries;
errors/fatals retain their severity independently of verbosity. UVM's standard
message-ID verbosity controls can select individual transaction streams.

The temporary module DUT supports only the DUT suite's serial master scenarios.
It is a simulation fixture, not production RTL. Its byte memory and timing do not
reuse the predictor. Other functional scenarios use independent class-based
source/endpoint fixtures, and unit fixtures remain in `tb/unit/`.

`amba_ahb_lite_assert_smoke.sv` is a direct, independent pin checker fixture with
legal and deliberate-failure cases. Run `tools/run_assertions.py --verilator
/path/to/verilator`. The separate interface contract smoke covers waits, ERROR,
timeouts and reset abort. Native assertion coverage/vacuity, X/Z behavior and
another simulator are not qualified. Functional counter hits do not prove coverage
closure. The optional MS connection is described in [ms/README.md](ms/README.md).

The recorded October 1 gates passed: 132 randomized functional runs (seeds 1, 17, 29, 43),
33 deterministic functional runs (seed 1), 3 unit tests, 10 DUT runs (seeds 1, 17)
and 5 optional digital bridge runs (seed 1). The 11 direct assertion fixtures and
interface contract passed too. These are historical results for their recorded
source fingerprints; rerun affected gates after changing source or tool dependencies.

## Response timing tests

Both tests use an active master, passive monitor, independent endpoint memory,
prediction and scoreboards. They write `0xDEADBEEF`, then read it back. The observer
checks the master result and monitor transaction separately, including payload,
OKAY response, zero sampled wait cycles and exactly one read completion/result.
Endpoint counts also require the timing fixture to execute exactly once.

| Test | Response timing | Required behavior |
| --- | --- | --- |
| `amba_ahb_lite_response_late_test` | HREADY stays low and HRDATA is zero through the falling edge; both settle before the next rising edge | Complete at that rising edge and return `0xDEADBEEF` with no extra wait |
| `amba_ahb_lite_response_edge_test` | The endpoint clears HRDATA through its clocking output at the read's completing rising edge | Master and monitor retain the pre-edge `0xDEADBEEF` response |

These tests are in the default functional regression. For a focused run:

```sh
python3 tools/run_regression.py --verilator /path/to/verilator \
    --tests response_late_test response_edge_test --seeds 1 17 29 43
```

The direct interface contract also runs both timing cases against an independent
native rising-edge receiver, and retires the ERROR response with a same-edge NBA.
Its receiver and the master must agree on data, response and exact completion
count. The late-ready fixture deliberately models slave propagation delay; the
reusable transport uses clocking blocks without simulator-specific settling waits.

October 14 local qualification passed all 35 functional tests at seeds 1, 17,
29 and 43 (140 runs), all 35 with randomization disabled at seed 1, the 3 unit
tests, 10 temporary-DUT runs at seeds 1 and 17, and 5 digital bridge runs at
seed 1. All 26 direct assertion cases and the expanded interface contract pass.
Both incorrect-skew sensitivity variants fail their targeted comparison against
the independent receiver. Strict elaboration of direct, functional and unit tops
has zero errors and no local VIP/testbench warnings. External UVM warnings remain
visible. The same complete runtime matrix was rerun after the local arithmetic,
enum and inherited-argument warning cleanup, with all gates passing and no
Verilator build warnings.
