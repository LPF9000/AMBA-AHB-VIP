"""Minimal adapter for the external TRNG-research DVFlow checkout.

DVFlow remains an external tool dependency.  This adapter only declares the
AHB filelist and does not copy or vendor the DVFlow implementation.
"""

from dvflow.project_adapter import ProjectAdapter


class DvFlowProjectAdapter(ProjectAdapter):
    """AHB VIP project policy layered over generic DVFlow commands."""

    adapter_id = "amba-ahb-vip"

    def gate_sim_default_tool(self) -> str:
        return "verilator"

    def selftest_experiment_spec(self) -> dict[str, object]:
        """Keep project preflight meaningful without a synthesis candidate."""

        return {
            "schema_version": 1,
            "experiment_id": "amba_ahb_vip_preflight",
            "description": "AHB-Lite VIP compile/preflight experiment.",
            "stage_profile": "synth-plan",
            "candidates": ["sv_uvm_baseline"],
            "heuristic": "project_preflight",
            "execution": {"synth_backend": "yosys", "synth_mode": "generic"},
            "analysis": {"objectives": [{"metric": "rtl_compile_status", "direction": "max", "weight": 1.0}]},
            "gates": {"must_pass": ["synth-plan"]},
        }


__all__ = ["DvFlowProjectAdapter"]
