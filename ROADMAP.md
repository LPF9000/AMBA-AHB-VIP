# AHB VIP roadmap

Current work is limited to AMBA 3 AHB-Lite, using ARM IHI 0033A. The initial
configuration uses 32-bit addresses and data, little-endian lanes, one master,
and one selected slave. Other AHB profiles and widths are future work.

The original five smoke tests now pass in a fresh local run, including reset
recovery. The expanded implementation and its 33-test regression remain under
review. Tests currently use behavioral endpoints; application DUT integration
will follow separately.

| Milestone | Status | Remaining work |
| --- | --- | --- |
| Reproduce the baseline | Complete locally | Preserve seed, tool versions, and results |
| Reset and recovery | Implemented; validation in progress | Close all reset timing and memory-policy cases |
| Address/data pipeline correlation | Implemented; validation in progress | Confirm identical transfers and overlapping waits |
| Directed AHB-Lite matrix | In progress | Close lanes, slave, ready, timeout, ERROR, and burst cases |
| Checker and lifecycle proof | In progress | Review negative cases and final stream completeness |
| Random regression and coverage | In progress | Run recorded seeds and review functional and code coverage |
| Application integration and portability | Future work | Exercise a real DUT and additional simulators |

Passing local tests establish evidence for the tested configuration. Interface
parameters and component availability do not establish broader support.
Expansion beyond AMBA 3 AHB-Lite will be planned after this baseline is reliable.
