# AHB VIP source layout

The reusable API uses `amba_ahb_*` names. Its current implemented profile is
AMBA 3 AHB-Lite, ARM IHI 0033A: 32-bit addresses and data, little-endian lanes,
one master and one selected slave. Family names do not imply support for other
AHB revisions or variants.

| Package | Responsibility |
| --- | --- |
| `amba_ahb_params_pkg` | Compiled widths, address/data types, protocol encodings, profile and revision |
| `amba_ahb_agent_pkg` | Items, typed agent configuration, sequencer, drivers, monitor, protocol checker, agent and reusable sequences |
| `amba_ahb_env_pkg` | Optional memory responder, predictor, scoreboards, coverage and environment configuration/topology |

Compile the parameter package before the interface and agent package. Compile
the environment package when you need its models or checking environment.
Class files are included by their owning package and must not also appear as
standalone compilation units. Each class has its own `.svh` file.

Reusable sequences live in `seq_lib/`. The agent package includes
`seq_lib/amba_ahb_seq_list.sv`, which includes the base sequence before its
derived single-transfer and burst sequences. The base sequence gets typed
agent configuration from the sequencer and constructs common transaction
intent. Drivers own all bus timing.

`amba_ahb_agent_cfg.profile` defaults to `ahb_compiled_profile`. Runtime width
settings must match the types in the parameter package. Validation rejects
unsupported profiles, non-32-bit widths, big-endian operation, and invalid
agent role or active/passive mode. Runtime settings cannot resize an interface.
Virtual interface types use the compiled address/data widths explicitly.

| Profile | Implementation |
| --- | --- |
| AMBA 3 AHB-Lite, IHI0033A, 32-bit little-endian, single master/selected slave | Implemented; behavioral regression and qualification limits are described in the testbench README |
| Legacy full AHB, later AHB extensions, wider transactions, big-endian operation or additional topologies | Future work; unsupported by the current configuration |

The main item carries stimulus and response fields. The observed item adds
transfer identity and completion metadata. The cycle item preserves raw sampled
phases for protocol checking, including IDLE and BUSY. These are distinct TLM
contracts; published and retained objects are copied to preserve snapshots.

The self-test code stays under `tb/`, with testbench sequences in `tb/seq_lib/`
and individual tests in `tb/tests/`. It is separate from the reusable agent.

## Pin-level assertions

Master and slave clocking outputs use `@(posedge HCLK)` with `output #0`.
The master and monitor inputs use `input #1step` at that edge. Drivers consume
the sampled current phase and schedule the next phase after DUT sampling, in
the Re-NBA region. Address acceptance and data completion remain separate.
Asynchronous reset assertion can still return pins to their reset values without
waiting for a clock. There are no simulator-specific response delays or caches.

`amba_ahb_lite_assert.sv` owns a passive accepted-address/data-phase decoder.
It connects phase snapshots and raw pins to the native
`amba_ahb_lite_protocol_check` container and sibling generic known/stable checks
from the `checkers/` submodule. Protocol rules cover reset, size/alignment,
response routing, two-cycle ERROR responses, waits, burst progression and
boundaries for the supported IHI 0033A profile. Byte masks select meaningful
read/write lanes. The transaction checker and independent scoreboards retain
separate semantic and completeness ownership.

The generic `stable_check` compares consecutive rising-edge samples; it cannot
detect a pulse that starts and ends between them. Library clock timing/gating
checks observe actual clock transitions. General bus setup/hold or glitch checks
are not implemented, and response data is not required to remain fixed throughout
a waited data phase. It must be valid at the completing edge.

Include `src` and `checkers/src` in the compiler search path. Compile the
assertion host once through the repository file list; its checker header is an
include fragment. Parameterized interface widths do not expand the implemented
32-bit transaction profile. Local simulation uses direct native declarations;
four-state and alternate-simulator qualification remain open.

Instantiate the `amba_ahb_lite_assert` module beside the bus interface in the
containing module and connect its raw pin ports. The integration owns its
`enable_i` control. [The functional top](../tb/tb.sv) and
[interface contract top](../tb/amba_ahb_lite_if_smoke.sv) show the complete wiring.
This keeps the module host in a legal SystemVerilog scope and lets integrations
choose pin checking independently of the interface BFM.
