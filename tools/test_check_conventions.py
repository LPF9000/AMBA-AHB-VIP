"""Exercise the convention gate with representative accidental source changes."""

from pathlib import Path
import shutil
import tempfile
import unittest

from tools.check_conventions import check


class ConventionGateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        original = Path(__file__).resolve().parents[1]
        for name in ("src", "tb", "checkers/src"):
            shutil.copytree(original / name, self.repo / name)
        for path in original.glob("amba_ahb_lite*.f"):
            shutil.copyfile(path, self.repo / path.name)

    def test_current_layout(self) -> None:
        self.assertEqual(check(self.repo), [])

    def test_missing_library_include(self) -> None:
        (self.repo / "checkers/src/known_check.svh").unlink()
        self.assertTrue(any("include does not resolve: known_check.svh" in message
                            for message in check(self.repo)))

    def test_sequence_pin_access(self) -> None:
        path = self.repo / "src/seq_lib/amba_ahb_single_seq.svh"
        path.write_text(path.read_text().replace("task body();", "task body();\n        agent_cfg.vif.HADDR = '0;"))
        self.assertTrue(any("must not access pins" in message for message in check(self.repo)))

    def test_duplicate_compilation(self) -> None:
        path = self.repo / "amba_ahb_lite_uvm.f"
        path.write_text(path.read_text() + "src/amba_ahb_item.svh\n")
        self.assertTrue(any("compiled independently" in message for message in check(self.repo)))

    def test_width_drift(self) -> None:
        path = self.repo / "tb/amba_ahb_lite_tb_cfg.svh"
        path.write_text(path.read_text().replace("ahb_addr_t base_addr", "logic [31:0] base_addr"))
        self.assertTrue(any("shared address/data typedefs" in message for message in check(self.repo)))

    def test_missing_factory_registration(self) -> None:
        path = self.repo / "tb/unit/amba_ahb_lite_tb_unit_checks.svh"
        path.write_text(path.read_text().replace("`uvm_component_utils(amba_ahb_lite_tb_unit_checks)", ""))
        self.assertTrue(any("factory registration" in message for message in check(self.repo)))

    def test_timescale_declaration_order(self) -> None:
        path = self.repo / "src/amba_ahb_lite_assert.sv"
        path.write_text(path.read_text().replace("    timeunit 1ns;",
                        "    import amba_ahb_params_pkg::*;\n    timeunit 1ns;", 1))
        self.assertTrue(any("must precede imports" in message for message in check(self.repo)))

    def test_callback_lifecycle(self) -> None:
        path = self.repo / "tb/unit/amba_ahb_lite_tb_unit_checks.svh"
        path.write_text(path.read_text().replace("uvm_report_cb::delete(null, report_policy);", ""))
        self.assertTrue(any("remove its global report callback" in message for message in check(self.repo)))


if __name__ == "__main__":
    unittest.main()
