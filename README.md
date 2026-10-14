# AMBA AHB VIP

SystemVerilog/UVM verification IP for Arm AMBA AHB. We are currently working
only on AMBA 3 AHB-Lite. The longer-term goal is to support other AHB versions
and variants, but they are outside the current implementation plan.

[Roadmap](ROADMAP.md) · [References](references/README.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Current implementation

The current baseline uses 32-bit addresses and data, little-endian lane mapping,
one master, and one selected slave. The interface has width parameters; the
transaction configuration rejects non-32-bit widths and big-endian operation.
Byte, halfword, and word transfers are included in the expanded local tests.

The source includes active master and slave drivers, a passive monitor,
pin-level SystemVerilog assertions, a transaction protocol checker, independent
prediction, scoreboards, coverage, and typed agent/environment configuration.
Shared types and compiled defaults live in one parameter package. The
[component layout](src/README.md) describes the reusable API.

Master and slave outputs use rising-edge clocking blocks with `output #0`.
Drivers and the passive monitor sample with `input #1step`, so each transfer
uses the values present before the rising edge, including responses that settle
after the falling edge. Updates caused by the completing edge belong to the
following cycle. The transport needs no response cache or settling delay.

Functional tests use typed virtual sequencers and parented child sequences.
The environment schedules initial reset, the test prepares the virtual sequence
in pre_main, and run starts traffic after reset. Constraint randomization is on
by default and can be disabled for deterministic scenarios. Monitor and scoreboard
transactions print as UVM tables at the default verbosity.

There are separate functional, component-unit and integration harnesses.
The [testbench top](tb/tb.sv) can select a small AHB memory slave;
optional [UVM-MS bridge wiring](tb/ms/README.md) provides a digital connection
view using an external standard package. No application IP or analog simulation
is qualified. Checker-rule parity, coverage closure, four-state assertions and
simulator portability remain open. See the [roadmap](ROADMAP.md).

## Assertion checkers

The independently implemented pin checker uses native SystemVerilog
`checker` containers for the supported IHI 0033A profile. One passive decoder
tracks accepted address phases and publishes the data-phase snapshots used by
protocol assertions and reusable masked data checks. UVM transaction checkers
and scoreboards provide independent semantic and completeness checks.

The library's stability assertions compare clock samples. Its clock timing and
gating checkers also check actual clock transitions, but it does not provide a
general bus-signal glitch checker. Intra-cycle response settling is permitted;
a separate timing contract is needed to check setup/hold windows or pulse widths.

The [sva-checkers library](checkers/README.md) is a pinned submodule at `checkers/`.
It provides 29 reusable families with accepted-event contracts, configurable
bounds and bounded reference state. Its language and runtime gates are separate
from the AHB consumer tests. Four-state, alternate-simulator, formal and full
assertion-activation qualification remain open; these are development baselines.

## Protocol reference

The current profile follows the AMBA 3 AHB-Lite specification, ARM IHI 0033A.
Prior reviews also consulted IHI0033C; later AHB extensions are outside this
profile. Bus widths, endianness, reset memory behavior, and timeout limits are
implementation or test configuration choices, not claims of complete support
for everything the specification permits.

## Getting started

The source is in `src/` and smoke test tops are in `tb/`. Use
`amba_ahb_lite.f` for the interface smoke and `amba_ahb_lite_uvm.f` for the UVM
harness; `amba_ahb_lite_unit.f` selects the isolated unit top.
UVM compilation requires a separately available UVM library.

The `./dv` launcher uses DVFlow v0.1.28, pinned as a submodule in `tools/dv`
and installed through this repository's uv environment. `DVFLOW_ROOT` can select another
DVFlow checkout. Verilator 5.052 or newer and an external UVM library are
required. Native tool installations and build outputs remain local. DVFlow repository
read access is required for recursive submodule checkout and this environment.
Public native-source CI uses the standalone runners and public checker dependency;
see [tooling notes](tools/README.md).

```sh
git submodule update --init --recursive
uv sync --locked
export PATH="$PWD/.toolchain/verilator-5.052/bin:$PATH"
./dv verify project --skip-source-check
./dv sim run --backend verilator --test amba_ahb_lite_topology_test
./dv sim regression --backend verilator --seeds 1 17 29 43
```

The PATH example selects an existing local installation; fresh clones need
their own tool installation. See [testbench notes](tb/README.md) for available
tests and [tooling notes](tools/README.md) for the DVFlow adapter.

## AMBA VIP collection

This repository is included as a submodule of
[AMBA-VIP](https://github.com/LPF9000/AMBA-VIP), which will bring the AMBA protocol
families together as they are implemented.
