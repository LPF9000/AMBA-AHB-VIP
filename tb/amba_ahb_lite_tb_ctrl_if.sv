// Testbench-only integration controls. UVM tests and sequences never access pins.
interface amba_ahb_lite_tb_ctrl_if(input logic clk);
    timeunit 1ns;
    timeprecision 1ps;
    logic reset_n = 1'b0;
    logic external_ready = 1'b1;

    task automatic release_reset();
        @(posedge clk);
        #1 reset_n = 1'b1;
    endtask

    task automatic pulse_reset();
        #2 reset_n = 1'b0;
        repeat (2) @(posedge clk);
        #1 reset_n = 1'b1;
    endtask
endinterface
