# AHB-Lite smoke and focused-test contract

`amba_ahb_lite_if_smoke.sv` is intentionally simulator-independent compile/
interface scaffolding. A UVM-capable Verilator installation should add tests
that instantiate `amba_ahb_lite_env`, provide a DUT or responder, and use
explicit seeds for this matrix:

| Test | Required observation |
| --- | --- |
| single read/write | NONSEQ address phase, completed data/response phase |
| wait states | stable address/control/write data; exact `wait_cycles` |
| ERROR | subordinate `ERROR,HREADYOUT=0` followed by completing ERROR |
| reset pending | driver abort, monitor reset event/generation, no cross-reset pair |
| timeout | `timed_out` distinct from `reset_abort` |
| fixed/INCR/WRAP burst | NONSEQ first, SEQ continuation, progression/1-KB rule |
| alignment/size | unsupported or unaligned request rejected and reported |
| passive agent | monitor/checker operate without sequencer/driver |

`amba_ahb_lite_uvm.f` and `amba_ahb_lite_uvm_smoke.sv` provide a real UVM
passive-topology smoke. The test proves typed virtual-interface/configuration
distribution and passive agent construction; active stimulus and endpoint
tests use the same top after a supported UVM simulator is installed.

The supported simulator baseline is Verilator >=5.052. The available local
Verilator 5.051-devel package compile is non-gating syntax/elaboration
evidence only; the launcher intentionally rejects it for runtime simulation.
