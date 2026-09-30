module amba_ahb_lite_uvm_smoke;
    import uvm_pkg::*;
    import amba_ahb_lite_pkg::*;
    import amba_ahb_lite_tb_pkg::*;
    timeunit 1ns;
    timeprecision 1ps;
    logic clk = 1'b0;
    amba_ahb_lite_tb_ctrl_if ctrl(clk);
    amba_ahb_lite_if bus(clk, ctrl.reset_n);
    string wave_path;

    always #5 clk = ~clk;
    assign bus.HREADY = bus.HREADYOUT && ctrl.external_ready;
    assign bus.HSEL = 1'b1;

    initial begin
        amba_ahb_lite_tb_cfg cfg;
        bus.assertions_enable = 1'b1;
        bus.HADDR = '0;
        bus.HWRITE = 1'b0;
        bus.HTRANS = AHB_IDLE;
        bus.HSIZE = AHB_WORD;
        bus.HBURST = AHB_SINGLE;
        bus.HPROT = 4'b0011;
        bus.HMASTLOCK = 1'b0;
        bus.HWDATA = '0;
        bus.HREADYOUT = 1'b1;
        bus.HRESP = AHB_OKAY;
        bus.HRDATA = '0;
        cfg = amba_ahb_lite_tb_cfg::type_id::create("cfg");
        cfg.vif = bus;
        cfg.ctrl = ctrl;
        uvm_config_db#(amba_ahb_lite_tb_cfg)::set(null, "uvm_test_top", "cfg", cfg);
        if ($value$plusargs("AHB_WAVES=%s", wave_path)) begin
            $dumpfile(wave_path);
            $dumpvars(0, amba_ahb_lite_uvm_smoke);
        end
        run_test();
    end

    initial begin
        #1ms;
        $fatal(1, "AHB regression watchdog expired");
    end
endmodule
