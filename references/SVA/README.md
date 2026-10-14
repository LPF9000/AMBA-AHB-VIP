# Assertion references

These sources cover SystemVerilog Assertions (SVA), reusable assertion checkers, and tools that parse, simulate, or prove assertions. Clause numbers below refer to IEEE Std 1800-2017, the local language baseline; check each tool's supported subset before relying on a property.

## Standards and checker libraries

- [IEEE Std 1800-2017 record](https://ieeexplore.ieee.org/abstract/document/8299595) — normative language reference for the local baseline. Clause 16 specifies assertions and clause 17 specifies checker declarations. IEEE marks this edition superseded. Accellera's [IEEE standards access page](https://www.accellera.org/downloads/ieee) identifies community standards available without charge through the IEEE Get program; an IEEE login and acceptance of access terms may be required.
- [IEEE Std 1800-2023](https://standards.ieee.org/ieee/1800/7743/) — current active SystemVerilog edition. Community access is available at no cost through the IEEE Get program; subscription access is also listed. This newer edition is not the basis for the local 2017 copy.
- [Accellera OVL downloads](https://www.accellera.org/downloads/standards/ovl) — official Open Verification Library 2.8.1 package and Library Reference Manual. The download is available without purchase after accepting Accellera's terms. OVL code is licensed under Apache 2.0; the terms distinguish library use from redistribution of Accellera standards material. See the [statement of use](https://accellera.org/downloads/standards/ovl/ovl-statement-of-use).

## Tool documentation

- [Verilator language support](https://verilator.org/guide/latest/languages.html) and [assertion options](https://verilator.org/guide/latest/exe_verilator.html) — implementation-specific parsing and execution support. The simulator and documentation are freely available; SVA and functional coverage support is partial and version-dependent.
- [slang documentation](https://www.sv-lang.com/) and [command-line reference](https://www.sv-lang.com/command-line-ref.html) — parsing, elaboration, and compiler options for an open-source SystemVerilog compiler. The tool and documentation are freely available; they are useful for compile checks, not a substitute for the standard or a simulator.
- [SymbiYosys documentation](https://symbiyosys.readthedocs.io/en/latest/) — formal setup, proof flows, and supported assertion constructs for the Yosys-based toolchain. The tool and documentation are publicly available without a paid license. Consult the documented subset before using a property.

## Local copies

Workspace-only copies of IEEE 1800-2017 and the Accellera OVL manual and quick references are kept under ignored `aidocs/references/SVA/`. They are not included in this repository.
