module amba_ahb_lite_if_smoke;
    timeunit 1ns;
    timeprecision 1ps;
    import amba_ahb_params_pkg::*;
    import amba_ahb_lite_tb_params_pkg::*;
    logic hclk = 1'b0;
    logic hresetn = 1'b0;
    amba_ahb_if bus(hclk, hresetn);
    bit assertions_enable = 1'b1;
    amba_ahb_lite_assert protocol_assertions (
        .clk_i(hclk), .rst_ni(hresetn), .enable_i(assertions_enable),
        .haddr_i(bus.HADDR), .hwrite_i(bus.HWRITE), .htrans_i(bus.HTRANS), .hsize_i(bus.HSIZE),
        .hburst_i(bus.HBURST), .hprot_i(bus.HPROT), .hmastlock_i(bus.HMASTLOCK), .hsel_i(bus.HSEL),
        .hwdata_i(bus.HWDATA), .hrdata_i(bus.HRDATA), .hready_i(bus.HREADY),
        .hreadyout_i(bus.HREADYOUT), .hresp_i(bus.HRESP)
    );
    assign bus.HREADY = bus.HREADYOUT;
    assign bus.HSEL = 1'b1;
    bit reference_pending;
    ahb_data_t reference_data;
    logic reference_resp;
    int unsigned reference_completions;

    // Independent synchronous receiver: capture pre-NBA pins exactly as RTL
    // does, without using any VIP clocking view or BFM state.
    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            reference_pending <= 1'b0;
            reference_data <= '0;
            reference_resp <= AHB_OKAY;
            reference_completions <= 0;
        end else if (bus.HREADY) begin
            if (reference_pending) begin
                reference_data <= bus.HRDATA;
                reference_resp <= bus.HRESP;
                reference_completions <= reference_completions + 1;
            end
            reference_pending <= bus.HTRANS[1];
        end
    end
    always @(negedge hresetn) begin
        bus.master_reset_idle();
        bus.slave_reset_ready();
    end

    always #(tb_clock_period / 2) hclk = ~hclk;

    task automatic respond_okay(int unsigned waits, ahb_data_t data);
        do @(posedge hclk);
        while (hresetn && !(bus.HTRANS inside {2'b10, 2'b11}));
        if (!hresetn)
            return;
        for (int unsigned i = 0; i < waits; i++) begin
            @(negedge hclk);
            bus.HREADYOUT = 1'b0;
            bus.HRESP = 1'b0;
        end
        @(negedge hclk);
        bus.HREADYOUT = 1'b1;
        bus.HRESP = 1'b0;
        bus.HRDATA = data;
    endtask

    task automatic respond_error();
        do @(posedge hclk);
        while (hresetn && !(bus.HTRANS inside {2'b10, 2'b11}));
        if (!hresetn)
            return;
        @(negedge hclk);
        bus.HREADYOUT = 1'b0;
        bus.HRESP = 1'b1;
        @(negedge hclk);
        bus.HREADYOUT = 1'b1;
        bus.HRESP = 1'b1;
        @(posedge hclk);
        bus.HRESP <= AHB_OKAY;
    endtask

    task automatic respond_late();
        do @(posedge hclk);
        while (!(bus.HTRANS inside {AHB_NONSEQ, AHB_SEQ}));
        bus.HREADYOUT <= 1'b0;
        bus.HRESP <= AHB_OKAY;
        bus.HRDATA <= '0;
        @(negedge hclk);
        #(tb_clock_period / 4);
        bus.HREADYOUT <= 1'b1;
        bus.HRDATA <= tb_timing_data;
    endtask

    task automatic respond_same_edge();
        do @(posedge hclk);
        while (!(bus.HTRANS inside {AHB_NONSEQ, AHB_SEQ}));
        bus.HREADYOUT <= 1'b1;
        bus.HRESP <= AHB_OKAY;
        bus.HRDATA <= tb_timing_data;
        @(posedge hclk);
        // A synchronous slave retires its response at the completing edge.
        bus.HRDATA <= '0;
    endtask

    task automatic respond_stalled();
        do @(posedge hclk);
        while (hresetn && !(bus.HTRANS inside {AHB_NONSEQ, AHB_SEQ}));
        if (!hresetn)
            return;
        @(negedge hclk);
        bus.HREADYOUT = 1'b0;
        bus.HRESP = AHB_OKAY;
    endtask

    task automatic master_transfer(input ahb_addr_t addr,
        output ahb_data_t data,
        output ahb_hresp_e resp,
        output int unsigned waits,
        output bit done,
        output bit aborted,
        output bit timed_out);
        bus.master_drive(addr, 1'b0, AHB_NONSEQ, AHB_WORD, AHB_SINGLE, ahb_default_prot, 1'b0, '0);
        bus.master_complete(1'b0, '0, tb_smoke_timeout_limit, data, resp, waits, done, aborted, timed_out);
    endtask

    initial begin
        ahb_data_t data;
        ahb_hresp_e resp;
        int unsigned waits;
        bit done, aborted, timed_out;
        int unsigned before_completions;
        bus.HREADYOUT = 1'b1;
        bus.HRESP = 1'b0;
        bus.HRDATA = '0;
        bus.master_idle();
        repeat (2) @(posedge hclk);
        #(tb_reset_release_delay) hresetn = 1'b1;

        fork
            respond_okay(tb_default_waits, tb_smoke_data);
            master_transfer(tb_smoke_addr, data, resp, waits, done, aborted, timed_out);
        join
        if (!done || aborted || timed_out || (waits != tb_default_waits) || (data != tb_smoke_data) || resp)
            $fatal(1, "AHB wait-state smoke failed");

        @(negedge hclk);
        before_completions = reference_completions;
        fork
            respond_late();
            master_transfer(tb_smoke_addr, data, resp, waits, done, aborted, timed_out);
        join
        @(negedge hclk);
        if (!done || aborted || timed_out || waits != 0 || resp !== AHB_OKAY ||
                data !== tb_timing_data || reference_data !== data ||
                reference_resp !== resp || reference_completions != before_completions + 1)
            $fatal(1, "AHB late-ready response disagrees with synchronous receiver");
        $display("AHB response_late PASS: receiver and master captured 0x%08x", data);

        before_completions = reference_completions;
        fork
            respond_same_edge();
            master_transfer(tb_smoke_addr, data, resp, waits, done, aborted, timed_out);
        join
        @(negedge hclk);
        if (!done || aborted || timed_out || waits != 0 || resp !== AHB_OKAY ||
                data !== tb_timing_data || reference_data !== data ||
                reference_resp !== resp || bus.HRDATA !== '0 ||
                reference_completions != before_completions + 1)
            $fatal(1, "AHB same-edge response replacement disagrees with synchronous receiver");
        $display("AHB response_edge PASS: response cleared, receiver and master retained 0x%08x", data);

        fork
            respond_error();
            master_transfer(tb_smoke_addr + ahb_data_bytes, data, resp, waits, done, aborted, timed_out);
        join
        @(negedge hclk);
        if (!done || !resp || aborted || timed_out)
            $fatal(1, "AHB two-cycle ERROR smoke failed");

        fork
            respond_stalled();
            master_transfer(tb_smoke_addr + 2 * ahb_data_bytes, data, resp, waits, done, aborted, timed_out);
        join
        if (!timed_out || done || aborted)
            $fatal(1, "AHB timeout smoke failed");

        @(negedge hclk);
        hresetn = 1'b0;
        repeat (2) @(posedge hclk);
        #(tb_reset_release_delay) hresetn = 1'b1;
        fork
            respond_stalled();
            master_transfer(tb_smoke_addr + 3 * ahb_data_bytes, data, resp, waits, done, aborted, timed_out);
            begin
                repeat (2) @(negedge hclk);
                hresetn = 1'b0;
                repeat (2) @(posedge hclk);
                #(tb_reset_release_delay) hresetn = 1'b1;
            end
        join
        if (!aborted || done || timed_out)
            $fatal(1, "AHB reset-abort smoke failed");
        $display("amba_ahb_lite_if_smoke PASS");
        $finish;
    end
endmodule
