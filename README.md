# AMBA AHB VIP

SystemVerilog/UVM verification IP for Arm AMBA AHB. We are currently working
only on AMBA 3 AHB-Lite. The longer-term goal is to support other AHB versions
and variants, but they are outside the current implementation plan.

[Roadmap](ROADMAP.md) · [Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)

## Current implementation

The current baseline uses 32-bit addresses and data, little-endian lane mapping,
one master, and one selected slave. The interface has width parameters; the
transaction configuration rejects non-32-bit widths and big-endian operation.
Byte, halfword, and word transfers are included in the expanded local tests.

The source includes active master and slave drivers, a passive monitor,
protocol checker, predictor, scoreboards, optional coverage, and typed agent
and environment configuration. Sequences describe transfers, drivers handle
bus timing, and monitors publish accepted, completed, and aborted observations.
The testbench uses independent behavioral endpoints to exercise the VIP.

A fresh run of the original five smoke tests passed with seed 1 under Verilator
5.052, including reset recovery. An expanded 33-test suite is being validated
locally. It covers pipelining, lanes, active slave responses, reset, timeouts,
bursts, and deliberate checking failures. Those implementation changes remain
under review; this is not yet complete protocol qualification.

Seed sweeps, coverage review, and simulator portability checks remain open.
No application DUT has been integrated. See the [roadmap](ROADMAP.md).

## Protocol reference

The current profile follows the AMBA 3 AHB-Lite specification, ARM IHI 0033A.
Prior reviews also consulted IHI0033C; later AHB extensions are outside this
profile. Bus widths, endianness, reset memory behavior, and timeout limits are
implementation or test configuration choices, not claims of complete support
for everything the specification permits.

## Getting started

The source is in `src/` and smoke test tops are in `tb/`. Use
`amba_ahb_lite.f` for the interface smoke and `amba_ahb_lite_uvm.f` for the UVM
harness. UVM compilation requires a separately available UVM library.

The existing `./dv` launcher uses an external DVFlow installation. It defaults
to a sibling `TRNG-research` checkout; set `DVFLOW_ROOT` to use another location.
The Verilator UVM path requires version 5.052 or newer. Local tools and build
outputs are not included in the repository.

```sh
export PATH="$PWD/.toolchain/verilator-5.052/bin:$PATH"
./dv verify project --skip-source-check
./dv sim run --backend verilator --test amba_ahb_lite_topology_test
```

The PATH example selects an existing local installation; fresh clones need
their own tool installation. See [testbench notes](tb/README.md) for available
tests and [tooling notes](tools/README.md) for the DVFlow adapter.

## AMBA VIP collection

This repository is included as a submodule of
[AMBA-VIP](https://github.com/LPF9000/AMBA-VIP), which will bring the AMBA protocol
families together as they are implemented.
