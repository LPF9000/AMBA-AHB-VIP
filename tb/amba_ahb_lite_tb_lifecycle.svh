class amba_ahb_lite_tb_lifecycle extends uvm_subscriber #(amba_ahb_item);
    `uvm_component_utils(amba_ahb_lite_tb_lifecycle)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_agent_cfg slave_cfg;
    protected uvm_event timeout_seen;

    function new(string name = "amba_ahb_lite_tb_lifecycle", uvm_component parent = null);
        super.new(name, parent);
        timeout_seen = new("timeout_seen");
    endfunction

    function void write(amba_ahb_item t);
        if (t.timed_out)
            timeout_seen.trigger();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (cfg == null || cfg.vif == null || cfg.ctrl == null)
            `uvm_fatal("AHB_CFG", "Lifecycle requires typed configuration and interfaces")
    endfunction

    task reset_scenario();
        if (cfg.expected_timeouts != 0)
            timeout_seen.wait_on();
        else if (cfg.reset_before_accept) begin
            wait (cfg.vif.HTRANS[1] === 1'b1);
        end else begin
            do @(cfg.vif.monitor_cb);
            while (!cfg.vif.monitor_cb.HREADY || !cfg.vif.monitor_cb.HTRANS[1] ||
                (cfg.scenario == TB_RESET_RETAIN && cfg.vif.monitor_cb.HADDR != cfg.base_addr));
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

    task prepare_initial_reset();
        if (cfg.reset_before_accept || cfg.scenario == TB_TIMEOUT_ADDRESS)
            cfg.ctrl.external_ready = 1'b0;
    endtask

    task initial_reset();
        repeat (tb_reset_cycles) @(posedge cfg.ctrl.clk);
        cfg.ctrl.release_reset();
        cfg.started.trigger();
    endtask

    task run_phase(uvm_phase phase);
        cfg.started.wait_on();
        if (cfg.reset_on_transfer || cfg.reset_before_accept || cfg.expected_timeouts != 0)
            reset_scenario();
    endtask
endclass
