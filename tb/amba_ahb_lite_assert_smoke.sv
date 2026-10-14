// Direct pin contract fixture, independent of the UVM monitor and drivers.
module amba_ahb_lite_assert_smoke;
    timeunit 1ns;
    timeprecision 1ps;
    import amba_ahb_params_pkg::*;
    import amba_ahb_lite_tb_params_pkg::*;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b1;
    ahb_addr_t addr = tb_base_addr;
    logic write_access = 1'b0;
    ahb_htrans_e trans = AHB_IDLE;
    ahb_hsize_e size = AHB_WORD;
    ahb_hresp_e resp = AHB_OKAY;
    ahb_data_t data = tb_transfer_data;
    ahb_hburst_e burst = AHB_SINGLE;
    logic [3:0] protection = ahb_default_prot;
    logic lock_access = 1'b0;
    logic selected = 1'b1;
    logic ready = 1'b1;
    logic readyout = 1'b1;
    string scenario;

    always #(tb_clock_period / 2) clk = ~clk;
    amba_ahb_lite_assert assertions (
        .clk_i(clk), .rst_ni(rst_n), .enable_i(enable), .haddr_i(addr),
        .hwrite_i(write_access), .htrans_i(trans), .hsize_i(size), .hburst_i(burst),
        .hprot_i(protection), .hmastlock_i(lock_access), .hsel_i(selected),
        .hwdata_i(data), .hrdata_i('0), .hready_i(ready), .hreadyout_i(readyout), .hresp_i(resp)
    );

    task automatic drive(ahb_htrans_e next_trans, bit next_ready,
            ahb_hresp_e next_resp = AHB_OKAY);
        @(negedge clk);
        trans = next_trans;
        ready = next_ready;
        readyout = next_ready;
        resp = next_resp;
    endtask

    initial begin
        if (!$value$plusargs("AHB_ASSERT_CASE=%s", scenario))
            scenario = "legal";
        repeat (tb_reset_cycles) @(posedge clk);
        #(tb_reset_release_delay) rst_n = 1'b1;
        if (scenario == "reset_idle" || scenario == "reset_ready") begin
            @(negedge clk);
            rst_n = 1'b0;
            if (scenario == "reset_idle")
                trans = AHB_NONSEQ;
            else
                readyout = 1'b0;
        end else if (scenario == "nontransfer") begin
            drive(AHB_IDLE, 1'b1);
            drive(AHB_IDLE, 1'b0);
            readyout = 1'b0;
        end else if (scenario inside {"byte_inactive", "byte_active"}) begin
            drive(AHB_NONSEQ, 1'b1);
            write_access = 1'b1;
            size = AHB_BYTE;
            addr = tb_base_addr + 1;
            drive(AHB_IDLE, 1'b0);
            drive(AHB_IDLE, 1'b0);
            if (scenario == "byte_active")
                data ^= ahb_data_t'(1 << ahb_byte_bits);
            else
                data ^= ahb_data_t'(1);
            drive(AHB_IDLE, 1'b1);
        end else if (scenario == "wait_idle_change") begin
            drive(AHB_NONSEQ, 1'b1);
            drive(AHB_IDLE, 1'b0);
            addr = tb_base_addr + 12;
            drive(AHB_IDLE, 1'b0);
            addr = tb_base_addr + 20;
            drive(AHB_NONSEQ, 1'b0);
            addr = tb_base_addr + 4;
            drive(AHB_NONSEQ, 1'b1);
            drive(AHB_IDLE, 1'b1);
        end else if (scenario == "route") begin
            drive(AHB_NONSEQ, 1'b1);
            drive(AHB_IDLE, 1'b0);
            readyout = 1'b1;
        end else if (scenario inside {"seq_without_burst", "busy_after_single"}) begin
            drive(AHB_NONSEQ, 1'b1);
            drive(scenario == "seq_without_burst" ? AHB_SEQ : AHB_BUSY, 1'b1);
            addr = tb_base_addr + 4;
        end else if (scenario == "start_boundary") begin
            drive(AHB_NONSEQ, 1'b1);
            burst = AHB_INCR4;
            addr = ahb_addr_t'(ahb_burst_boundary_bytes - ahb_data_bytes);
        end else if (scenario inside {"burst_address", "burst_control", "early_end",
                "wrap4", "incr4", "busy_wait", "wait_type", "error_cancel"}) begin
            drive(AHB_NONSEQ, 1'b1);
            burst = scenario == "wrap4" ? AHB_WRAP4 : AHB_INCR4;
            addr = scenario == "wrap4" ? tb_base_addr + 12 : tb_base_addr;
            if (scenario == "early_end") begin
                drive(AHB_IDLE, 1'b1);
            end else if (scenario == "error_cancel") begin
                drive(AHB_SEQ, 1'b0, AHB_ERROR);
                addr = tb_base_addr + 4;
                drive(AHB_IDLE, 1'b1, AHB_ERROR);
                drive(AHB_IDLE, 1'b1);
            end else begin
                if (scenario inside {"busy_wait", "wait_type"}) begin
                    drive(AHB_BUSY, 1'b0);
                    addr = tb_base_addr + 4;
                    if (scenario == "wait_type")
                        drive(AHB_NONSEQ, 1'b0);
                    else
                        drive(AHB_SEQ, 1'b0);
                end
                drive(AHB_SEQ, 1'b1);
                addr = scenario == "wrap4" ? tb_base_addr : tb_base_addr + 4;
                if (scenario == "burst_address")
                    addr += 4;
                if (scenario == "burst_control")
                    protection ^= 1;
                drive(AHB_SEQ, 1'b1);
                addr += 4;
                drive(AHB_SEQ, 1'b1);
                addr += 4;
                drive(AHB_IDLE, 1'b1);
            end
        end else begin
            drive(AHB_NONSEQ, 1'b1);
            write_access = 1'b1;
            if (scenario == "alignment")
                addr = tb_base_addr + 1;
            if (scenario == "size")
                size = AHB_DWORD;
            if (scenario inside {"error_first", "error_second"}) begin
                drive(AHB_IDLE, scenario == "error_first", AHB_ERROR);
                if (scenario == "error_second")
                    drive(AHB_IDLE, 1'b0, AHB_ERROR);
            end else if (scenario inside {"wait_address", "wait_write", "legal", "disabled"}) begin
                drive(AHB_NONSEQ, 1'b0);
                addr = tb_base_addr + ahb_data_bytes;
                write_access = 1'b0;
                if (scenario == "disabled")
                    enable = 1'b0;
                drive(AHB_NONSEQ, 1'b0);
                if (scenario inside {"wait_address", "disabled"})
                    addr += ahb_data_bytes;
                if (scenario == "wait_write")
                    data = tb_bad_data;
                drive(AHB_NONSEQ, 1'b1);
                drive(AHB_IDLE, 1'b0, AHB_ERROR);
                drive(AHB_IDLE, 1'b1, AHB_ERROR);
                drive(AHB_IDLE, 1'b1);
            end
        end
        repeat (tb_reset_cycles) @(posedge clk);
        #(tb_reset_release_delay);
        $display("AHB_ASSERT_SMOKE PASS %s", scenario);
        $finish;
    end
endmodule : amba_ahb_lite_assert_smoke
