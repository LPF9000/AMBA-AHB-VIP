# AMBA AHB VIP roadmap

The current target is ARM IHI 0033A AMBA 3 AHB-Lite: 32-bit, little-endian,
one master and one selected slave. Family API names and interface parameters
are not claims of support for other AHB variants or transaction widths.

| Milestone | Status | Remaining work |
| --- | --- | --- |
| Reusable UVM structure | Implemented; local gates pass | Review extension/configuration boundaries and conventions |
| Directed reset, pipeline, lanes, wait, ERROR and bursts | Implemented | Preserve reproducible evidence and close rule-specific gaps |
| Synchronous clocking and response timing | Rising-edge output #0/input #1step; both timing tests and current local gates pass | Alternate-simulator scheduling and four-state qualification |
| Reusable checker library | 29 native checker families implemented in pinned submodule | Complete per-rule boundary/activation, four-state, formal and alternate-simulator qualification |
| Independent protocol checking | Pin SVA and UVM transaction checks implemented | Complete starting-checker rule parity; qualify X/Z and assertion coverage |
| Normal UVM test flow | Implemented | Maintain reset/main sequencing, typed virtual sequencers and child ownership |
| Unit and functional harness separation | Implemented | Keep synthetic fixtures out of functional testcase packages |
| Default constraint randomization | Implemented | Run recorded seeds and deterministic opt-out; review functional/code coverage |
| Transaction tables and messaging | Tables implemented | Audit verbosity, IDs, duplicate output and severity policy |
| Temporary digital DUT integration | Implemented | Replace the simulation memory slave with application IP |
| Optional UVM-MS connection | Digital bridge/core/proxy implemented | Qualify standard typeless ports; analog testing is outside current scope |
| Waveform inspection | Released DVFlow inspection/conversion commands; local GTKWave sessions validated | Evaluate Surfer and provision/version native viewers |
| Reusable formal protocol properties | Native protocol assertions implemented; proof harnesses pending | Role assumptions/assertions, proof/cover harnesses, counterexamples and frontend/vacuity review |
| Broader DVFlow capabilities | Planned in shared tooling | Fuzzing, clocks/startup, GLS/X propagation, faults, timing/power, and native Ctrl+C quit behavior |
| Portability and production qualification | Open | Alternate simulator, full checker/coverage review and real-IP integration |

Detailed test selection and controls are in [testbench notes](tb/README.md).
Passing local gates apply to the recorded source/configuration; they do not
establish complete protocol qualification or analog support.

Recorded October 1 evidence includes 132 randomized functional runs across four seeds,
33 deterministic functional runs, 3 unit tests, 10 temporary-DUT runs and 5 digital
bridge runs. The independent SVA fixtures and interface contract also pass.
These results apply to the documented 32-bit AHB-Lite slice under Verilator 5.052.

October 14 qualification of the synchronous drive model passed 140 randomized
functional runs, 35 deterministic runs, 3 unit tests, 10 temporary-DUT runs,
5 digital bridge runs, 26 assertion cases and the expanded interface contract.
Strict SystemVerilog elaboration reports zero errors, with warnings still open.
Generic bus glitch/setup/hold checking remains a separate checker-library gap.
