module tb #(parameter bit use_simple_slave = 1'b0);
    timeunit 1ns;
    timeprecision 1ps;
    import uvm_pkg::*;
    import amba_ahb_params_pkg::*;
    import amba_ahb_agent_pkg::*;
    import amba_ahb_env_pkg::*;
    import amba_ahb_lite_tb_params_pkg::*;
    import amba_ahb_lite_tb_pkg::*;
    import amba_ahb_lite_test_pkg::*;
    logic clk = 1'b0;
    amba_ahb_lite_tb_ctrl_if ctrl(clk);
    amba_ahb_if bus(clk, ctrl.reset_n);
    bit assertions_enable = 1'b1;
    amba_ahb_lite_assert protocol_assertions (
        .clk_i(clk), .rst_ni(ctrl.reset_n), .enable_i(assertions_enable),
        .haddr_i(bus.HADDR), .hwrite_i(bus.HWRITE), .htrans_i(bus.HTRANS), .hsize_i(bus.HSIZE),
        .hburst_i(bus.HBURST), .hprot_i(bus.HPROT), .hmastlock_i(bus.HMASTLOCK), .hsel_i(bus.HSEL),
        .hwdata_i(bus.HWDATA), .hrdata_i(bus.HRDATA), .hready_i(bus.HREADY),
        .hreadyout_i(bus.HREADYOUT), .hresp_i(bus.HRESP)
    );
    string wave_path;

    always #(tb_clock_period / 2) clk = ~clk;
    assign bus.HREADY = bus.HREADYOUT && ctrl.external_ready;
    assign bus.HSEL = 1'b1;

    if (use_simple_slave) begin : gen_dut
`ifdef AHB_UVM_MS
        wire [ahb_addr_width-1:0] dut_addr;
        wire dut_write, dut_selected, dut_ready, dut_readyout, dut_resp, dut_mastlock;
        wire [1:0] dut_trans;
        wire [2:0] dut_size, dut_burst;
        wire [3:0] dut_prot;
        wire [ahb_data_width-1:0] dut_wdata, dut_rdata;
        amba_ahb_lite_ms_bridge bridge (
            .bus(bus), .addr(dut_addr), .write(dut_write), .trans(dut_trans),
            .size(dut_size), .burst(dut_burst), .prot(dut_prot), .mastlock(dut_mastlock),
            .wdata(dut_wdata), .selected(dut_selected), .ready(dut_ready),
            .readyout(dut_readyout), .resp(dut_resp), .rdata(dut_rdata)
        );
        amba_ahb_lite_simple_slave dut (
            .clk(clk), .reset_n(ctrl.reset_n), .selected(dut_selected),
            .ready(dut_ready), .addr(dut_addr), .write_access(dut_write),
            .trans(ahb_htrans_e'(dut_trans)), .size(ahb_hsize_e'(dut_size)),
            .wdata(dut_wdata), .wait_cycles(ctrl.dut_wait_cycles),
            .inject_error(ctrl.dut_inject_error), .error_addr(ctrl.dut_error_addr),
            .readyout(dut_readyout), .resp(dut_resp), .rdata(dut_rdata)
        );
`else
        amba_ahb_lite_simple_slave dut (
            .clk(clk), .reset_n(ctrl.reset_n), .selected(bus.HSEL),
            .ready(bus.HREADY), .addr(bus.HADDR), .write_access(bus.HWRITE),
            .trans(ahb_htrans_e'(bus.HTRANS)), .size(ahb_hsize_e'(bus.HSIZE)),
            .wdata(bus.HWDATA), .wait_cycles(ctrl.dut_wait_cycles),
            .inject_error(ctrl.dut_inject_error), .error_addr(ctrl.dut_error_addr),
            .readyout(bus.HREADYOUT), .resp(bus.HRESP), .rdata(bus.HRDATA)
        );
`endif
    end

    initial begin
        amba_ahb_lite_tb_cfg cfg;
        bus.HADDR = '0;
        bus.HWRITE = 1'b0;
        bus.HTRANS = AHB_IDLE;
        bus.HSIZE = AHB_WORD;
        bus.HBURST = AHB_SINGLE;
        bus.HPROT = ahb_default_prot;
        bus.HMASTLOCK = 1'b0;
        bus.HWDATA = '0;
        if (!use_simple_slave) begin
            bus.HREADYOUT = 1'b1;
            bus.HRESP = AHB_OKAY;
            bus.HRDATA = '0;
        end
        cfg = amba_ahb_lite_tb_cfg::type_id::create("cfg");
        void'($value$plusargs("DVFLOW_RANDOMIZE=%b", cfg.randomize_sequences));
        cfg.use_simple_slave = use_simple_slave;
`ifdef AHB_UVM_MS
        if (use_simple_slave)
            cfg.ms_proxy = gen_dut.bridge.proxy;
`endif
        cfg.vif = bus;
        cfg.ctrl = ctrl;
        uvm_config_db#(amba_ahb_lite_tb_cfg)::set(null, "uvm_test_top", "cfg", cfg);
        if ($value$plusargs("AHB_WAVES=%s", wave_path)) begin
            $dumpfile(wave_path);
            $dumpvars(0, tb);
        end
        run_test();
    end

    initial begin
        #(tb_watchdog);
        $fatal(1, "AHB regression watchdog expired");
    end
endmodule
