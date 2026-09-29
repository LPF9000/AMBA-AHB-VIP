# AHB VIP roadmap

The goal is parameterized SystemVerilog/UVM VIP for all AHB versions and
variants in the Arm AMBA specifications. We are starting with AMBA 3 AHB-Lite
and will expand through explicit protocol profiles and a tested support matrix.

## Current status

The repository contains an initial 32-bit AHB-Lite implementation, including
transactions, active/passive agents, drivers, monitoring, protocol checks,
prediction, scoreboards, coverage scaffolding, and smoke tests.

Earlier local validation recorded passing interface and passive-topology
smokes under Verilator 5.052. Those results are a starting point; they do not
establish complete protocol support or portability. The initial repository
import does not change protocol behavior.

| Milestone | Status | Completion gate |
| --- | --- | --- |
| Import the existing AHB-Lite source and smoke harness | Source available | Preserve source and document build dependencies |
| Establish a reproducible AHB-Lite baseline | In progress | Run smoke tests from a clean checkout and record tool versions |
| Validate active AHB-Lite behavior | Planned | Directed read/write, pipelining, waits, ERROR, reset, timeout, burst, size/alignment, and passive-mode tests |
| Close the AHB-Lite verification plan | Planned | DUT-backed regressions, explicit seeds, assertions, checker negative tests, and coverage evidence |
| Parameterize transactions and data lanes | Planned | Width/endian support matrix, legal configuration checks, and regressions for each supported configuration |
| Add the remaining AHB versions and variants | Planned | Arm revision/feature matrix and focused tests for each added profile |
| Establish simulator portability and releases | Planned | Documented simulator results and versioned support guarantees |

## Next work

Prove address/data phase correlation with back-to-back transfers. Cover global
HREADY versus local HREADYOUT, two-cycle ERROR, pending-transfer reset flush,
and timeout handling through the active UVM path. Check that failed or aborted
writes do not mutate predictor or responder state.

After that baseline is reliable, define the profile matrix for legacy full AHB,
AHB-Lite, and later AHB extensions. Record arbitration, response encoding,
signal sets, widths, and topology requirements separately for each applicable
specification revision. Configurability alone does not count as verified support.

The [AMBA-VIP roadmap](https://github.com/LPF9000/AMBA-VIP/blob/setup/initial-vip-import/ROADMAP.md)
tracks the wider protocol collection. Dates will be added when implementation
and validation scope are concrete.
