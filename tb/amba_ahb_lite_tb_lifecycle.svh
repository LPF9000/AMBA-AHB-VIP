class amba_ahb_lite_tb_lifecycle extends uvm_subscriber #(amba_ahb_lite_item);
    `uvm_component_utils(amba_ahb_lite_tb_lifecycle)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_lite_agent_config slave_cfg;
    protected uvm_event timeout_seen;

    function new(string name = "amba_ahb_lite_tb_lifecycle", uvm_component parent = null);
        super.new(name, parent);
        timeout_seen = new("timeout_seen");
    endfunction

    function void write(amba_ahb_lite_item item);
        if (item.timed_out)
            timeout_seen.trigger();
    endfunction

    task reset_scenario();
        if (cfg.expected_timeouts != 0)
            timeout_seen.wait_on();
        else if (cfg.reset_before_accept) begin
            wait (cfg.vif.HTRANS[1] === 1'b1);
        end else begin
            do @(cfg.vif.monitor_cb);
            while (!cfg.vif.monitor_cb.HREADY || !cfg.vif.monitor_cb.HTRANS[1] ||
                (cfg.scenario == TB_RESET_RETAIN && cfg.vif.monitor_cb.HADDR != 32'h100));
            if (cfg.reset_on_error) begin
                do @(cfg.vif.monitor_cb);
                while (cfg.vif.monitor_cb.HRESP != AHB_ERROR);
            end else begin
                @(cfg.vif.monitor_cb);
            end
        end
        repeat (cfg.reset_pulses)
            cfg.ctrl.pulse_reset();
        cfg.waits = 0;
        if (slave_cfg != null)
            slave_cfg.default_wait_cycles = 0;
        cfg.inject_error = 1'b0;
        cfg.ctrl.external_ready = 1'b1;
        cfg.recovery_ready.trigger();
    endtask

    task global_ready_scenario();
        wait (cfg.vif.HTRANS[1] === 1'b1);
        cfg.ctrl.external_ready = 1'b0;
        repeat (cfg.global_waits) @(cfg.vif.monitor_cb);
        @(negedge cfg.ctrl.clk);
        cfg.ctrl.external_ready = 1'b1;
    endtask

    task run_phase(uvm_phase phase);
        if (cfg.reset_before_accept || cfg.scenario == TB_TIMEOUT_ADDRESS)
            cfg.ctrl.external_ready = 1'b0;
        repeat (2) @(posedge cfg.ctrl.clk);
        cfg.ctrl.release_reset();
        cfg.started.trigger();
        if (cfg.reset_on_transfer || cfg.reset_before_accept || cfg.expected_timeouts != 0)
            reset_scenario();
        else if (cfg.global_waits != 0)
            global_ready_scenario();
    endtask
endclass
