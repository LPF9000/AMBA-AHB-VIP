# External DVFlow integration

The `./dv` launcher uses the existing local DVFlow checkout from
`TRNG-research/tools/dv` (override with `DVFLOW_ROOT`). DVFlow source is not
copied into this repository. The project-specific `dvflow.json` and adapter
only describe this VIP's filelist and Verilator default.

The checked local references are TRNG-research revision `20ab5d1` and its
`tools/dv` revision `d353522`; keep these external and update them through the
TRNG-research toolchain owner rather than copying DVFlow sources here.

Examples from the repository root:

```sh
./dv sim run --backend verilator --preflight-only
./dv sim run --backend verilator --test test_amba_ahb_lite_smoke
```

Until a UVM-capable Verilator harness and external UVM root are selected, the
standalone interface smoke remains the supported local smoke. It can be built
and run with `CCACHE_DISABLE=1` when the system ccache directory is read-only:

```sh
verilator --lint-only --timing --Wall --Wno-fatal \
    --top-module amba_ahb_lite_if_smoke \
    src/amba_ahb_lite_if.sv tb/amba_ahb_lite_if_smoke.sv
```

The executable smoke top is `amba_ahb_lite_if_smoke`; its checked-in test
covers waits, two-cycle ERROR, timeout, and reset abort.

The UVM path requires Verilator 5.052 or newer. Verilator 5.052 was released
2026-09-05 and adds UVM 2020-3.2 support; see the
[official revision history](https://verilator.org/guide/latest/changes.html).
The launcher checks the actual binary version for every `sim` command and
accepts an explicit `DVFLOW_VERILATOR_BIN` override.
