class amba_ahb_lite_base_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_base_test)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_lite_tb_env env;
    amba_ahb_lite_scenario_vseq seq;

    function new(string name = "amba_ahb_lite_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void configure();
        cfg.scenario = TB_ACTIVE;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_tb_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Test requires typed integration configuration")
        configure();
        cfg.use_slave_vip = cfg.scenario inside {TB_SLAVE, TB_SLAVE_WAIT, TB_SLAVE_SCRIPT,
            TB_SLAVE_ERROR, TB_SLAVE_RESET, TB_SLAVE_LANES, TB_SLAVE_RANDOM};
        cfg.use_batch_source = cfg.scenario inside {TB_SLAVE, TB_SLAVE_WAIT,
            TB_SLAVE_SCRIPT, TB_PIPELINE, TB_PIPELINE_WAIT, TB_BURSTS, TB_BURST_ERROR};
        cfg.waits = (cfg.scenario inside {TB_WAIT, TB_PIPELINE_WAIT, TB_SLAVE_WAIT, TB_SLAVE_SCRIPT}) ? tb_default_waits : 0;
        cfg.inject_error = cfg.scenario inside {TB_ERROR, TB_RESET_ERROR, TB_SLAVE_ERROR, TB_BURST_ERROR, TB_RANDOM, TB_SLAVE_RANDOM};
        if (cfg.scenario == TB_BURST_ERROR)
            cfg.error_addr = cfg.burst_addr;
        if (cfg.scenario inside {TB_RANDOM, TB_SLAVE_RANDOM})
            cfg.waits = cfg.randomize_sequences ? $urandom_range(tb_random_wait_limit, 0) : tb_default_waits;
        if (cfg.scenario == TB_REJECT)
            cfg.expected_rejects = 3;
        cfg.reset_on_error = cfg.scenario == TB_RESET_ERROR;
        cfg.reset_on_transfer = cfg.scenario inside {
            TB_RESET_WRITE, TB_RESET_READ, TB_RESET_ERROR, TB_RESET_RETAIN, TB_RESET_REPEAT, TB_SLAVE_RESET};
        cfg.reset_before_accept = cfg.scenario == TB_RESET_ADDRESS;
        cfg.clear_memory = cfg.scenario != TB_RESET_RETAIN;
        if (cfg.reset_on_transfer) begin
            cfg.waits = cfg.reset_on_error ? 0 : tb_reset_waits;
            cfg.expected_aborts = 1;
            cfg.expected_resets = 2;
        end
        if (cfg.reset_before_accept)
            cfg.expected_resets = 2;
        if (cfg.scenario == TB_RESET_REPEAT) begin
            cfg.reset_pulses = 2;
            cfg.expected_resets = 3;
        end
        if (cfg.scenario == TB_READY)
            cfg.waits = tb_global_waits;
        if (cfg.scenario == TB_LONG_WAIT)
            cfg.waits = tb_long_waits;
        if (cfg.scenario inside {TB_TIMEOUT_ADDRESS, TB_TIMEOUT_DATA}) begin
            cfg.expected_timeouts = 1;
            cfg.expected_resets = 2;
            if (cfg.scenario == TB_TIMEOUT_DATA) begin
                cfg.waits = tb_timeout_waits;
                cfg.expected_aborts = 1;
            end
        end
        uvm_config_db#(amba_ahb_lite_tb_cfg)::set(this, "env", "cfg", cfg);
        env = amba_ahb_lite_tb_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_root::get().set_timeout(tb_watchdog);
        if (env.virtual_sequencer == null)
            `uvm_fatal("AHB_TOPOLOGY", "Functional environment requires virtual sequencer")
    endfunction

    task reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        cfg.started.wait_on();
        phase.drop_objection(this);
    endtask

    task pre_main_phase(uvm_phase phase);
        seq = amba_ahb_lite_scenario_vseq::type_id::create("seq");
        seq.set_sequencer(env.virtual_sequencer);
        if (cfg.randomize_sequences && (seq.randomize() != 1))
            `uvm_fatal("AHB_RANDOMIZE", "Virtual sequence randomization failed")
        cfg.main_ready.trigger();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        cfg.main_ready.wait_on();
        seq.start(env.virtual_sequencer);
        phase.drop_objection(this);
    endtask
endclass
