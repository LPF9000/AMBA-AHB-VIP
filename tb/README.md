# AHB-Lite tests

The current suite targets AMBA 3 AHB-Lite with 32-bit addresses/data,
little-endian lanes, one master and one selected slave. It uses independent
behavioral source and endpoint components, plus supplemental VIP-to-VIP cases.
The active slave driver is exercised. No application DUT is included.

All 33 registered tests pass locally under Verilator 5.052 at seeds 1, 17, 29
and 43 (132 runs). This covers topology, read/write, pipelined identical
transfers, waits, global ready, byte/halfword/word lanes, automatic/scripted
slave responses, ERROR, reset recovery and retention, timeout, bursts/BUSY,
rejected requests, negative checker fixtures, copying, and seeded legal traffic.
Coverage review and remaining behavior checks are still in progress.

Run the full suite with a separately available UVM library:

```sh
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --seeds 1 17 29 43 --waves
```

Use `--tests active_smoke_test reset_smoke_test` to select cases. The runner's
`--help` lists all registered names. Reports contain seeds, commands, return
codes, UVM counts, functional counters, and optional waves. Passing requires
zero unexpected UVM errors/fatals and an emitted functional report.

`amba_ahb_lite_uvm.f` selects the UVM testbench. The top owns clock setup;
contained components own source, endpoint and lifecycle timing. Tests select
configuration, sequences and objections; analysis components own verdicts.

Transaction data is packed in the low payload bytes. Drivers place it in the
address-selected bus lanes, and monitors extract those lanes. Memory retention
on reset is a configured model policy, not an AHB guarantee. Timeout limits
are verification bounds and are distinct from bus responses.

The direct interface contract test is `amba_ahb_lite_if_smoke.sv`. It exercises
waits, two-cycle ERROR, timeout and reset abort without UVM. Four-state X/Z
validation and additional simulator qualification remain unrun. Functional
bin hits and code coverage inputs do not establish coverage closure.
