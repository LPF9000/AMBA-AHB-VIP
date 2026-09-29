# AMBA AHB VIP

SystemVerilog/UVM verification IP for Arm AMBA AHB. The goal is to support the
different AHB versions and variants through explicit, parameterized protocol
configurations. Development starts with AMBA 3 AHB-Lite.

[Roadmap](ROADMAP.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Current implementation

The first implementation assumes one master and one selected slave, with
32-bit addresses and transactions. The signal interface has width parameters,
but the transaction layer does not yet support wider configurations.

The source includes master and slave drivers, a passive monitor, protocol
checker, predictor, scoreboards, optional coverage, and typed agent and
environment configuration. It was ported from an existing pyuvm AHB testbench.
Sequences describe transfers, drivers handle bus timing, and monitors publish
completed observations for independent checking.

This is an early implementation. Interface and passive UVM topology smoke tests
are available. Active end-to-end regressions, DUT integration, and coverage
closure remain open; see the [roadmap](ROADMAP.md).

## Getting started

The source is in `src/` and smoke test tops are in `tb/`. The filelists are
`amba_ahb_lite.f` and `amba_ahb_lite_uvm.f`. UVM compilation requires a
simulator-provided or separately installed UVM library.

The existing `./dv` launcher uses an external DVFlow installation. It defaults
to a sibling `TRNG-research` checkout; set `DVFLOW_ROOT` to use another location.
The Verilator UVM path requires version 5.052 or newer. The toolchain and build
outputs are local and are not included in the repository.

```sh
./dv verify project --skip-source-check
./dv sim run --backend verilator --test amba_ahb_lite_topology_test
```

See [testbench notes](tb/README.md) for the focused test matrix and
[tooling notes](tools/README.md) for the existing DVFlow adapter.

## AMBA VIP collection

This repository is also included as a submodule of
[AMBA-VIP](https://github.com/LPF9000/AMBA-VIP), which will bring the AMBA protocol
families together as they are implemented.
