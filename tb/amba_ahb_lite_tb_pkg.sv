package amba_ahb_lite_tb_pkg;
    timeunit 1ns;
    timeprecision 1ps;
    import uvm_pkg::*;
    import amba_ahb_lite_pkg::*;
    `include "uvm_macros.svh"
    typedef enum {
        TB_TOPOLOGY, TB_ACTIVE, TB_WAIT, TB_ERROR, TB_RESET_WRITE,
        TB_RESET_READ, TB_RESET_ERROR, TB_RESET_RETAIN, TB_RESET_REPEAT,
        TB_RESET_ADDRESS, TB_PIPELINE, TB_PIPELINE_WAIT, TB_LANES,
        TB_SLAVE, TB_SLAVE_WAIT, TB_SLAVE_SCRIPT, TB_READY,
        TB_TIMEOUT_ADDRESS, TB_TIMEOUT_DATA, TB_BURSTS, TB_NEGATIVE,
        TB_COPY, TB_CONFIG, TB_RANDOM, TB_LONG_WAIT, TB_CHECKS_DISABLED,
        TB_SERIAL_BURSTS, TB_SLAVE_ERROR, TB_SLAVE_RESET, TB_SLAVE_LANES,
        TB_SLAVE_RANDOM, TB_BURST_ERROR, TB_REJECT
    } ahb_tb_scenario_e;
    `include "amba_ahb_lite_tb_cfg.svh"
    `include "amba_ahb_lite_tb_sequences.svh"
    `include "amba_ahb_lite_tb_source.svh"
    `include "amba_ahb_lite_tb_endpoint.svh"
    `include "amba_ahb_lite_tb_lifecycle.svh"
    `include "amba_ahb_lite_tb_observer.svh"
    `include "amba_ahb_lite_tb_unit_checks.svh"
    `include "amba_ahb_lite_tb_env.svh"
    `include "amba_ahb_lite_tb_tests.svh"
endpackage
