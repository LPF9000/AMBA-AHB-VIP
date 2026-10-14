# UVM references

These sources support decisions about UVM component ownership, TLM connections, phases, configuration, factory use, and reusable sequence structure. The UVM class reference and the repository's configured UVM library define API behavior; methodology guides provide context and examples.

## Standards and guides

- [Accellera UVM downloads](https://www.accellera.org/downloads/standards/uvm) — official UVM class references, reference implementations, and user guides, including UVM 1.2. Documents and implementations are offered for download without purchase; the UVM reference implementation is Apache 2.0 licensed. The page also lists IEEE 1800.2-based releases.
- [UVM 1.2 User's Guide](https://www.accellera.org/images/downloads/standards/uvm/uvm_users_guide_1.2.pdf) — official guide to testbench roles, TLM, reusable components, configuration, sequences, checking, and coverage. Available directly without purchase.
- [IEEE 1800.2-2020 UVM standard](https://standards.ieee.org/ieee/62530-2/11429/1800.2/7567/) — active normative UVM language reference. IEEE provides the PDF at no cost through its Get program; an IEEE login and acceptance of access terms may be required. Subscription access is also available.
- [Siemens Verification Academy UVM Cookbook](https://verificationacademy.com/cookbook/) — practical chapters on agents, TLM, sequences, scoreboards, and testbench structure. Browsing requires a Verification Academy account. Some chapters require full access; Siemens describes full-access accounts as free, with professional details and possible review.

## UVM examples

- [OpenTitan SPI agent](https://github.com/lowRISC/opentitan/tree/master/hw/dv/sv/spi_agent) and [I2C agent](https://github.com/lowRISC/opentitan/tree/master/hw/dv/sv/i2c_agent) — public source examples for agent composition, typed configuration, sequence libraries, and monitors. They are methodology examples, not AHB requirements.
- [OpenTitan TL-UL package](https://github.com/lowRISC/opentitan/blob/master/hw/ip/tlul/rtl/tlul_pkg.sv) and [TL-UL source and documentation](https://github.com/lowRISC/opentitan/tree/master/hw/ip/tlul) — examples of shared protocol types and compile-time width packages. TL-UL is a different protocol and is relevant only as a package-organization reference. Consult the OpenTitan license for reuse terms.

## Local copies

Workspace-only copies of the UVM 1.2 User's Guide and Siemens cookbook PDF are kept under ignored `aidocs/references/UVM/`. They are not included in this repository.
