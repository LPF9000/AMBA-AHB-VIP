class amba_ahb_lite_base_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_base_test)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_lite_tb_env env;

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
        cfg.waits = (cfg.scenario inside {TB_WAIT, TB_PIPELINE_WAIT, TB_SLAVE_WAIT, TB_SLAVE_SCRIPT}) ? 2 : 0;
        cfg.inject_error = cfg.scenario inside {TB_ERROR, TB_RESET_ERROR, TB_SLAVE_ERROR, TB_BURST_ERROR, TB_RANDOM, TB_SLAVE_RANDOM};
        if (cfg.scenario == TB_BURST_ERROR)
            cfg.error_addr = 32'h200;
        if (cfg.scenario inside {TB_RANDOM, TB_SLAVE_RANDOM})
            cfg.waits = $urandom_range(4, 0);
        if (cfg.scenario == TB_REJECT)
            cfg.expected_rejects = 3;
        cfg.reset_on_error = cfg.scenario == TB_RESET_ERROR;
        cfg.reset_on_transfer = cfg.scenario inside {
            TB_RESET_WRITE, TB_RESET_READ, TB_RESET_ERROR, TB_RESET_RETAIN, TB_RESET_REPEAT, TB_SLAVE_RESET};
        cfg.reset_before_accept = cfg.scenario == TB_RESET_ADDRESS;
        cfg.clear_memory = cfg.scenario != TB_RESET_RETAIN;
        if (cfg.reset_on_transfer) begin
            cfg.waits = cfg.reset_on_error ? 0 : 4;
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
            cfg.global_waits = 3;
        if (cfg.scenario == TB_LONG_WAIT)
            cfg.waits = 20;
        if (cfg.scenario inside {TB_TIMEOUT_ADDRESS, TB_TIMEOUT_DATA}) begin
            cfg.expected_timeouts = 1;
            cfg.expected_resets = 2;
            if (cfg.scenario == TB_TIMEOUT_DATA) begin
                cfg.waits = 12;
                cfg.expected_aborts = 1;
            end
        end
        uvm_config_db#(amba_ahb_lite_tb_cfg)::set(this, "env", "cfg", cfg);
        env = amba_ahb_lite_tb_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_tb_scenario_seq seq;
        amba_ahb_lite_tb_batch_seq batch_seq;
        amba_ahb_lite_tb_response_seq response_seq;
        phase.raise_objection(this);
        cfg.started.wait_on();
        if (env.unit_checks != null) begin
            env.unit_checks.done.wait_on();
        end else if (cfg.scenario != TB_TOPOLOGY) begin
            if (cfg.use_batch_source) begin
                batch_seq = amba_ahb_lite_tb_batch_seq::type_id::create("batch_seq");
                batch_seq.cfg = cfg;
                if (cfg.scenario == TB_SLAVE_SCRIPT) begin
                    response_seq = amba_ahb_lite_tb_response_seq::type_id::create("response_seq");
                    fork
                        batch_seq.start(env.source_sequencer);
                        response_seq.start(env.vip.agent.sequencer);
                    join
                end else begin
                    batch_seq.start(env.source_sequencer);
                end
            end else begin
                seq = amba_ahb_lite_tb_scenario_seq::type_id::create("seq");
                seq.cfg = cfg;
                if (env.stimulus_vip == null)
                    seq.start(env.vip.agent.sequencer);
                else
                    seq.start(env.stimulus_vip.agent.sequencer);
            end
        end
        phase.drop_objection(this);
    endtask
endclass

class amba_ahb_lite_topology_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_topology_test)

    function new(string name = "amba_ahb_lite_topology_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_TOPOLOGY;
    endfunction
endclass

class amba_ahb_lite_active_smoke_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_active_smoke_test)

    function new(string name = "amba_ahb_lite_active_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_ACTIVE;
    endfunction
endclass

class amba_ahb_lite_wait_smoke_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_wait_smoke_test)

    function new(string name = "amba_ahb_lite_wait_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_WAIT;
    endfunction
endclass

class amba_ahb_lite_error_smoke_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_error_smoke_test)

    function new(string name = "amba_ahb_lite_error_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_ERROR;
    endfunction
endclass

class amba_ahb_lite_reset_smoke_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_smoke_test)

    function new(string name = "amba_ahb_lite_reset_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_WRITE;
    endfunction
endclass

class amba_ahb_lite_reset_read_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_read_test)

    function new(string name = "amba_ahb_lite_reset_read_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_READ;
    endfunction
endclass

class amba_ahb_lite_reset_error_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_error_test)

    function new(string name = "amba_ahb_lite_reset_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_ERROR;
    endfunction
endclass

class amba_ahb_lite_reset_retain_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_retain_test)

    function new(string name = "amba_ahb_lite_reset_retain_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_RETAIN;
    endfunction
endclass

class amba_ahb_lite_reset_repeat_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_repeat_test)

    function new(string name = "amba_ahb_lite_reset_repeat_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_REPEAT;
    endfunction
endclass

class amba_ahb_lite_reset_address_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_address_test)

    function new(string name = "amba_ahb_lite_reset_address_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_ADDRESS;
    endfunction
endclass

class amba_ahb_lite_pipeline_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_pipeline_test)

    function new(string name = "amba_ahb_lite_pipeline_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_PIPELINE;
    endfunction
endclass

class amba_ahb_lite_pipeline_wait_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_pipeline_wait_test)

    function new(string name = "amba_ahb_lite_pipeline_wait_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_PIPELINE_WAIT;
    endfunction
endclass

class amba_ahb_lite_lanes_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_lanes_test)

    function new(string name = "amba_ahb_lite_lanes_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_LANES;
    endfunction
endclass

class amba_ahb_lite_slave_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_test)

    function new(string name = "amba_ahb_lite_slave_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_SLAVE;
    endfunction
endclass

class amba_ahb_lite_slave_wait_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_wait_test)

    function new(string name = "amba_ahb_lite_slave_wait_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_SLAVE_WAIT;
    endfunction
endclass

class amba_ahb_lite_slave_script_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_script_test)

    function new(string name = "amba_ahb_lite_slave_script_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_SLAVE_SCRIPT;
    endfunction
endclass

class amba_ahb_lite_global_ready_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_global_ready_test)

    function new(string name = "amba_ahb_lite_global_ready_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_READY;
    endfunction
endclass

class amba_ahb_lite_address_timeout_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_address_timeout_test)

    function new(string name = "amba_ahb_lite_address_timeout_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_TIMEOUT_ADDRESS;
    endfunction
endclass

class amba_ahb_lite_data_timeout_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_data_timeout_test)

    function new(string name = "amba_ahb_lite_data_timeout_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_TIMEOUT_DATA;
    endfunction
endclass

class amba_ahb_lite_bursts_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_bursts_test)

    function new(string name = "amba_ahb_lite_bursts_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_BURSTS;
    endfunction
endclass

class amba_ahb_lite_negative_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_negative_test)

    function new(string name = "amba_ahb_lite_negative_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_NEGATIVE;
    endfunction
endclass

class amba_ahb_lite_copy_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_copy_test)

    function new(string name = "amba_ahb_lite_copy_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_COPY;
    endfunction
endclass

class amba_ahb_lite_config_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_config_test)

    function new(string name = "amba_ahb_lite_config_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_CONFIG;
    endfunction
endclass

class amba_ahb_lite_random_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_random_test)

    function new(string name = "amba_ahb_lite_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RANDOM;
    endfunction
endclass

class amba_ahb_lite_long_wait_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_long_wait_test)

    function new(string name = "amba_ahb_lite_long_wait_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_LONG_WAIT;
    endfunction
endclass

class amba_ahb_lite_checks_disabled_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_checks_disabled_test)

    function new(string name = "amba_ahb_lite_checks_disabled_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_CHECKS_DISABLED;
    endfunction
endclass

class amba_ahb_lite_serial_bursts_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_serial_bursts_test)
    function new(string name = "amba_ahb_lite_serial_bursts_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_SERIAL_BURSTS;
    endfunction
endclass

class amba_ahb_lite_slave_error_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_error_test)
    function new(string name = "amba_ahb_lite_slave_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_SLAVE_ERROR;
    endfunction
endclass

class amba_ahb_lite_slave_reset_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_reset_test)
    function new(string name = "amba_ahb_lite_slave_reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_SLAVE_RESET;
    endfunction
endclass

class amba_ahb_lite_slave_lanes_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_lanes_test)
    function new(string name = "amba_ahb_lite_slave_lanes_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_SLAVE_LANES;
    endfunction
endclass

class amba_ahb_lite_slave_random_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_random_test)
    function new(string name = "amba_ahb_lite_slave_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_SLAVE_RANDOM;
    endfunction
endclass

class amba_ahb_lite_burst_error_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_burst_error_test)
    function new(string name = "amba_ahb_lite_burst_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_BURST_ERROR;
    endfunction
endclass

class amba_ahb_lite_reject_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reject_test)
    function new(string name = "amba_ahb_lite_reject_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void configure();
        cfg.scenario = TB_REJECT;
    endfunction
endclass
