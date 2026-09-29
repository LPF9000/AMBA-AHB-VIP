module amba_ahb_lite_if_smoke;
    logic hclk = 1'b0;
    logic hresetn = 1'b0;
    amba_ahb_lite_if bus(hclk, hresetn);
    assign bus.HREADY = bus.HREADYOUT;

    always #5 hclk = ~hclk;

    task automatic respond_okay(int unsigned waits, logic [31:0] data);
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
    endtask

    task automatic master_transfer(input logic [31:0] addr,
                                                                  output logic [31:0] data,
                                                                  output logic resp,
                                                                  output int unsigned waits,
                                                                  output bit done,
                                                                  output bit aborted,
                                                                  output bit timed_out);
        bus.master_drive(addr, 1'b0, 2'b10, 3'b010, 3'b000, 4'b0011, 1'b0, '0);
        bus.master_complete(1'b0, '0, 8, data, resp, waits, done, aborted, timed_out);
    endtask

    initial begin
        logic [31:0] data;
        logic resp;
        int unsigned waits;
        bit done, aborted, timed_out;
        bus.HREADYOUT = 1'b1;
        bus.HRESP = 1'b0;
        bus.HRDATA = '0;
        bus.master_idle();
        repeat (2) @(posedge hclk);
        hresetn = 1'b1;

        fork
            respond_okay(2, 32'h1234_5678);
            master_transfer(32'h1000, data, resp, waits, done, aborted, timed_out);
        join
        if (!done || aborted || timed_out || (waits != 2) || (data != 32'h1234_5678) || resp)
            $fatal(1, "AHB wait-state smoke failed");

        fork
            respond_error();
            master_transfer(32'h1004, data, resp, waits, done, aborted, timed_out);
        join
        if (!done || !resp || aborted || timed_out)
            $fatal(1, "AHB two-cycle ERROR smoke failed");

        bus.HREADYOUT = 1'b0;
        fork
            master_transfer(32'h1008, data, resp, waits, done, aborted, timed_out);
            begin
                repeat (10) @(posedge hclk);
            end
        join_any
        disable fork;
        if (!timed_out || done || aborted)
            $fatal(1, "AHB timeout smoke failed");

        bus.HREADYOUT = 1'b0;
        fork
            master_transfer(32'h100c, data, resp, waits, done, aborted, timed_out);
            begin
                repeat (2) @(negedge hclk);
                hresetn = 1'b0;
                repeat (2) @(negedge hclk);
                hresetn = 1'b1;
            end
        join_any
        disable fork;
        if (!aborted || done || timed_out)
            $fatal(1, "AHB reset-abort smoke failed");
        $display("amba_ahb_lite_if_smoke PASS");
        $finish;
    end
endmodule
