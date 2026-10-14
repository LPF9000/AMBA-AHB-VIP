// Testbench-only integration controls. UVM tests and sequences never access pins.
interface amba_ahb_lite_tb_ctrl_if(input logic clk);
    timeunit 1ns;
    timeprecision 1ps;
    import amba_ahb_lite_tb_params_pkg::*;
    logic reset_n = 1'b0;
    logic external_ready = 1'b1;
    int unsigned dut_wait_cycles;
    bit dut_inject_error;
    amba_ahb_params_pkg::ahb_addr_t dut_error_addr;

    task automatic release_reset();
        @(posedge clk);
        #(tb_reset_release_delay) reset_n = 1'b1;
    endtask

    task automatic pulse_reset();
        #(tb_reset_assert_delay) reset_n = 1'b0;
        repeat (tb_reset_cycles) @(posedge clk);
        #(tb_reset_release_delay) reset_n = 1'b1;
    endtask
endinterface
