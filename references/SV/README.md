# SystemVerilog references

These sources cover the language baseline used by the VIP, including packages, interfaces, classes, assertions, coverage, and compile-time constructs. Use the AHB and UVM catalogs for protocol and methodology guidance.

- [IEEE Std 1800-2017 record](https://ieeexplore.ieee.org/abstract/document/8299595) — normative language reference used by the local workspace copy. IEEE marks the 2017 edition superseded. Accellera's [IEEE standards access page](https://www.accellera.org/downloads/ieee) identifies community standards available without charge through the IEEE Get program; an IEEE login and acceptance of access terms may be required.
- [IEEE Std 1800-2023](https://standards.ieee.org/ieee/1800/7743/) — current active edition. Community access is available at no cost through the IEEE Get program; subscription access is also listed. The current local reference copy is the 2017 edition.
- [Verilator language guide](https://verilator.org/guide/latest/languages.html) — current support notes for the freely available, open-source simulator and linter. Feature support is partial and version-dependent.
- [slang documentation](https://www.sv-lang.com/) — freely available documentation for an open-source SystemVerilog compiler, including parsing, elaboration, and command-line use. Use it for additional compile checks, not as the normative language definition.
- [OpenTitan SPI agent](https://github.com/lowRISC/opentitan/tree/master/hw/dv/sv/spi_agent), [I2C agent](https://github.com/lowRISC/opentitan/tree/master/hw/dv/sv/i2c_agent), and [TL-UL package](https://github.com/lowRISC/opentitan/blob/master/hw/ip/tlul/rtl/tlul_pkg.sv) — public examples for file layout, package composition, configuration, and shared types. Consult the OpenTitan license for reuse terms.

A workspace-only copy of IEEE 1800-2017 is kept under ignored `aidocs/references/SV/`; no standard PDF is included here.
