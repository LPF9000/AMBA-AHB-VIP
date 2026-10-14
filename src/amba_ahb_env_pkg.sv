package amba_ahb_env_pkg;
    timeunit 1ns;
    timeprecision 1ps;
    import uvm_pkg::*;
    import amba_ahb_params_pkg::*;
    import amba_ahb_agent_pkg::*;
    export amba_ahb_agent_pkg::*;
    `include "uvm_macros.svh"

    `include "amba_ahb_memory_model.svh"
    `include "amba_ahb_env_cfg.svh"
    `include "amba_ahb_stream_scoreboard.svh"
    `include "amba_ahb_predictor.svh"
    `include "amba_ahb_scoreboard.svh"
    `include "amba_ahb_coverage.svh"
    `include "amba_ahb_env.svh"
endpackage : amba_ahb_env_pkg
