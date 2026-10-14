# Optional UVM-MS connection

The DUT top can insert a bridge between the digital AHB interface and the
small memory DUT. It follows the external-interface organization in
[Accellera UVM-MS 1.0, clauses 4.2 and 5](https://accellera.org/images/downloads/standards/uvm-ms/UVM-MS_1.0.pdf):
one proxy per bridge, a separately replaceable core, interface/core links through
hierarchical references, and typeless DUT ports on supporting simulators.

The bridge-owned concrete proxy implements the abstract `uvm_ms_proxy` extension.
The top places that handle in the typed testbench configuration before `run_test`;
the environment receives the same cfg through a scoped config_db entry. The AHB
agent keeps its ordinary virtual interface. The current proxy queries the core's
abstraction; it contains no invented analog stimuli or controls.

Supply the official external package and includes from
[Accellera's UVM-MS download](https://accellera.org/downloads/standards/uvm-ms):

```sh
python3 tools/run_regression.py --verilator /path/to/verilator \
    --uvm-root /path/to/uvm/src --suite integration --output sim/ms_digital \
    --uvm-ms-root /path/to/uvm-ms
```

The package is not vendored. Without this option the digital top uses direct
connections. Verilator 5.052 rejects `interconnect`; its guarded digital build
uses `wire` ports. The standard `interconnect` branch has not been validated on
an AMS-capable simulator. This adaptation establishes digital connectivity only.

For an analog integration, retain the bridge/proxy boundary, replace the core
view with the required RNM/AMS conversion, and supply the model-specific control
API and simulator. Analog testing is outside this task. The local TRNG ngspice
flows provide deck/run/trace tools; they do not establish UVM-MS co-simulation.
