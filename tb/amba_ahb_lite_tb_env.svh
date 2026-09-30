class amba_ahb_lite_tb_env extends uvm_env;
    `uvm_component_utils(amba_ahb_lite_tb_env)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_lite_env vip;
    amba_ahb_lite_env stimulus_vip;
    amba_ahb_lite_env_config vip_cfg;
    amba_ahb_lite_tb_lifecycle lifecycle;
    amba_ahb_lite_tb_endpoint endpoint;
    amba_ahb_lite_tb_source source;
    uvm_sequencer #(amba_ahb_lite_tb_batch_item) source_sequencer;
    amba_ahb_lite_tb_observer observer;
    amba_ahb_lite_tb_unit_checks unit_checks;

    function new(string name = "amba_ahb_lite_tb_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        amba_ahb_lite_tb_error_policy policy;
        amba_ahb_lite_env_config source_cfg;
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_tb_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Testbench environment requires typed configuration")
        vip_cfg = amba_ahb_lite_env_config::type_id::create("vip_cfg");
        vip_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        vip_cfg.agent_cfg.vif = cfg.vif;
        vip_cfg.agent_cfg.flush_on_reset = cfg.clear_memory;
        vip_cfg.agent_cfg.role = cfg.use_slave_vip ? AHB_SLAVE : AHB_MASTER;
        vip_cfg.agent_cfg.is_active = (cfg.scenario == TB_TOPOLOGY ||
            cfg.scenario inside {TB_NEGATIVE, TB_COPY, TB_CONFIG} ||
            (cfg.use_batch_source && !cfg.use_slave_vip)) ? UVM_PASSIVE : UVM_ACTIVE;
        vip_cfg.external_intent = cfg.use_batch_source || cfg.use_slave_vip;
        vip_cfg.enable_predictor = !(cfg.scenario inside {TB_TOPOLOGY, TB_NEGATIVE, TB_COPY, TB_CONFIG});
        vip_cfg.enable_scoreboard = vip_cfg.enable_predictor;
        vip_cfg.enable_coverage = 1'b1;
        vip_cfg.agent_cfg.checks_enable = !(cfg.scenario inside {TB_NEGATIVE, TB_COPY, TB_CONFIG, TB_CHECKS_DISABLED});
        if (cfg.expected_timeouts != 0)
            vip_cfg.agent_cfg.max_wait_cycles = 4;
        if (cfg.inject_error) begin
            policy = amba_ahb_lite_tb_error_policy::type_id::create("policy");
            policy.error_addr = cfg.error_addr;
            vip_cfg.agent_cfg.response_policy = policy;
        end
        if (cfg.use_slave_vip) begin
            vip_cfg.agent_cfg.responder_model = amba_ahb_lite_memory_model::type_id::create("model");
            vip_cfg.agent_cfg.default_wait_cycles = cfg.waits;
            vip_cfg.agent_cfg.automatic_response = cfg.scenario != TB_SLAVE_SCRIPT;
        end
        uvm_config_db#(amba_ahb_lite_env_config)::set(this, "vip", "cfg", vip_cfg);
        vip = amba_ahb_lite_env::type_id::create("vip", this);
        lifecycle = amba_ahb_lite_tb_lifecycle::type_id::create("lifecycle", this);
        lifecycle.cfg = cfg;
        if (cfg.use_slave_vip)
            lifecycle.slave_cfg = vip_cfg.agent_cfg;
        observer = amba_ahb_lite_tb_observer::type_id::create("observer", this);
        observer.cfg = cfg;
        if (!cfg.use_slave_vip) begin
            endpoint = amba_ahb_lite_tb_endpoint::type_id::create("endpoint", this);
            endpoint.cfg = cfg;
        end
        if (cfg.use_slave_vip && !cfg.use_batch_source) begin
            source_cfg = amba_ahb_lite_env_config::type_id::create("source_cfg");
            source_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("source_agent_cfg");
            source_cfg.agent_cfg.vif = cfg.vif;
            source_cfg.agent_cfg.checks_enable = 1'b0;
            source_cfg.enable_predictor = 1'b0;
            source_cfg.enable_scoreboard = 1'b0;
            source_cfg.enable_stream_scoreboard = 1'b0;
            uvm_config_db#(amba_ahb_lite_env_config)::set(this, "stimulus_vip", "cfg", source_cfg);
            stimulus_vip = amba_ahb_lite_env::type_id::create("stimulus_vip", this);
        end
        if (cfg.use_batch_source) begin
            source_sequencer = new("source_sequencer", this);
            source = amba_ahb_lite_tb_source::type_id::create("source", this);
            source.cfg = cfg;
        end
        if (cfg.scenario inside {TB_NEGATIVE, TB_COPY, TB_CONFIG}) begin
            unit_checks = amba_ahb_lite_tb_unit_checks::type_id::create("unit_checks", this);
            unit_checks.cfg = cfg;
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vip.observed_export.connect(observer.analysis_export);
        vip.reset_export.connect(observer.reset_export);
        vip.agent.monitor.aborted_ap.connect(observer.aborted_export);
        if (vip.agent.master_driver != null) begin
            vip.agent.master_driver.result_ap.connect(observer.result_export);
            vip.agent.master_driver.result_ap.connect(lifecycle.analysis_export);
        end
        if (stimulus_vip != null) begin
            stimulus_vip.agent.master_driver.request_ap.connect(vip.intent_export);
            stimulus_vip.agent.master_driver.result_ap.connect(observer.result_export);
            stimulus_vip.agent.master_driver.result_ap.connect(lifecycle.analysis_export);
        end
        if (source != null) begin
            source.seq_item_port.connect(source_sequencer.seq_item_export);
            source.request_ap.connect(vip.intent_export);
        end
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        if (vip_cfg.agent_cfg.is_active == UVM_PASSIVE &&
                (vip.agent.master_driver != null || vip.agent.slave_driver != null ||
                 vip.agent.sequencer != null))
            `uvm_error("AHB_TOPOLOGY", "Passive VIP constructed an active path")
        if (!vip_cfg.agent_cfg.checks_enable && vip.agent.protocol_checker != null)
            `uvm_error("AHB_TOPOLOGY", "Disabled checker was constructed")
    endfunction
endclass
