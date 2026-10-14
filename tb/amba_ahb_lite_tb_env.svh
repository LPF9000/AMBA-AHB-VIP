class amba_ahb_lite_tb_env extends uvm_env;
    `uvm_component_utils(amba_ahb_lite_tb_env)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_env vip;
    amba_ahb_env stimulus_vip;
    amba_ahb_env_cfg vip_cfg;
    amba_ahb_lite_tb_lifecycle lifecycle;
    amba_ahb_lite_tb_endpoint endpoint;
    amba_ahb_lite_tb_source source;
    uvm_sequencer #(amba_ahb_lite_tb_batch_item) source_sequencer;
    amba_ahb_lite_tb_observer observer;
    amba_ahb_lite_virtual_sequencer virtual_sequencer;

    function new(string name = "amba_ahb_lite_tb_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        amba_ahb_lite_tb_error_policy policy;
        amba_ahb_env_cfg source_cfg;
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_tb_cfg)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Testbench environment requires typed configuration")
        vip_cfg = amba_ahb_env_cfg::type_id::create("vip_cfg");
        vip_cfg.agent_cfg = amba_ahb_agent_cfg::type_id::create("agent_cfg");
        vip_cfg.agent_cfg.vif = cfg.vif;
        vip_cfg.agent_cfg.flush_on_reset = cfg.clear_memory;
        vip_cfg.agent_cfg.role = cfg.use_slave_vip ? AHB_SLAVE : AHB_MASTER;
        vip_cfg.agent_cfg.is_active = (cfg.scenario == TB_TOPOLOGY ||
            (cfg.use_batch_source && !cfg.use_slave_vip)) ? UVM_PASSIVE : UVM_ACTIVE;
        vip_cfg.external_intent = cfg.use_batch_source || cfg.use_slave_vip;
        vip_cfg.enable_predictor = cfg.scenario != TB_TOPOLOGY;
        vip_cfg.enable_scoreboard = vip_cfg.enable_predictor;
        vip_cfg.enable_coverage = 1'b1;
        vip_cfg.agent_cfg.checks_enable = cfg.scenario != TB_CHECKS_DISABLED;
        if (cfg.expected_timeouts != 0)
            vip_cfg.agent_cfg.max_wait_cycles = cfg.timeout_limit;
        if (cfg.inject_error) begin
            policy = amba_ahb_lite_tb_error_policy::type_id::create("policy");
            policy.error_addr = cfg.error_addr;
            vip_cfg.agent_cfg.response_policy = policy;
        end
        if (cfg.use_slave_vip) begin
            vip_cfg.agent_cfg.responder_model = amba_ahb_memory_model::type_id::create("model");
            vip_cfg.agent_cfg.default_wait_cycles = cfg.waits;
            vip_cfg.agent_cfg.automatic_response = cfg.scenario != TB_SLAVE_SCRIPT;
        end
        uvm_config_db#(amba_ahb_env_cfg)::set(this, "vip", "cfg", vip_cfg);
        vip = amba_ahb_env::type_id::create("vip", this);
        lifecycle = amba_ahb_lite_tb_lifecycle::type_id::create("lifecycle", this);
        lifecycle.cfg = cfg;
        if (cfg.use_slave_vip)
            lifecycle.slave_cfg = vip_cfg.agent_cfg;
        observer = amba_ahb_lite_tb_observer::type_id::create("observer", this);
        observer.cfg = cfg;
        if (!cfg.use_slave_vip && !cfg.use_simple_slave) begin
            endpoint = amba_ahb_lite_tb_endpoint::type_id::create("endpoint", this);
            endpoint.cfg = cfg;
        end
        if (cfg.use_slave_vip && !cfg.use_batch_source) begin
            source_cfg = amba_ahb_env_cfg::type_id::create("source_cfg");
            source_cfg.agent_cfg = amba_ahb_agent_cfg::type_id::create("source_agent_cfg");
            source_cfg.agent_cfg.vif = cfg.vif;
            source_cfg.agent_cfg.checks_enable = 1'b0;
            source_cfg.enable_predictor = 1'b0;
            source_cfg.enable_scoreboard = 1'b0;
            source_cfg.enable_stream_scoreboard = 1'b0;
            uvm_config_db#(amba_ahb_env_cfg)::set(this, "stimulus_vip", "cfg", source_cfg);
            stimulus_vip = amba_ahb_env::type_id::create("stimulus_vip", this);
        end
        if (cfg.use_batch_source) begin
            source_sequencer = new("source_sequencer", this);
            source = amba_ahb_lite_tb_source::type_id::create("source", this);
            source.cfg = cfg;
        end
        virtual_sequencer = amba_ahb_lite_virtual_sequencer::type_id::create("virtual_sequencer", this);
        virtual_sequencer.cfg = cfg;
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.use_slave_vip) begin
            if (stimulus_vip != null)
                virtual_sequencer.m_sqr = stimulus_vip.agent.sequencer;
        end else begin
            virtual_sequencer.m_sqr = vip.agent.sequencer;
        end
        virtual_sequencer.slave_sqr = cfg.use_slave_vip ? vip.agent.sequencer : null;
        virtual_sequencer.source_sqr = source_sequencer;
        vip.intent_ap.connect(observer.intent_export);
        vip.observed_ap.connect(observer.analysis_export);
        vip.reset_ap.connect(observer.reset_export);
        vip.agent.monitor.aborted_ap.connect(observer.aborted_export);
        if (vip.agent.master_driver != null) begin
            observer.bind_expected_reports(vip.agent.master_driver);
            vip.agent.master_driver.result_ap.connect(observer.result_export);
            vip.agent.master_driver.result_ap.connect(lifecycle.analysis_export);
        end
        if (stimulus_vip != null) begin
            observer.bind_expected_reports(stimulus_vip.agent.master_driver);
            stimulus_vip.agent.master_driver.request_ap.connect(vip.intent_ap);
            stimulus_vip.agent.master_driver.result_ap.connect(observer.result_export);
            stimulus_vip.agent.master_driver.result_ap.connect(lifecycle.analysis_export);
        end
        if (source != null) begin
            source.seq_item_port.connect(source_sequencer.seq_item_export);
            source.request_ap.connect(vip.intent_ap);
        end
    endfunction

    task pre_reset_phase(uvm_phase phase);
        lifecycle.prepare_initial_reset();
    endtask

    task reset_phase(uvm_phase phase);
        lifecycle.initial_reset();
    endtask

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
`ifdef AHB_UVM_MS
        if (cfg.use_simple_slave && (cfg.ms_proxy == null || cfg.ms_proxy.get_abstraction() != "digital"))
            `uvm_fatal("AHB_MS", "Digital bridge harness requires its typed proxy")
`endif
        if (cfg.use_simple_slave) begin
            if (cfg.use_slave_vip || cfg.use_batch_source || cfg.reset_on_transfer)
                `uvm_fatal("AHB_TOPOLOGY", "Simple DUT harness supports serial master scenarios only")
            cfg.ctrl.dut_wait_cycles = cfg.waits;
            cfg.ctrl.dut_inject_error = cfg.inject_error;
            cfg.ctrl.dut_error_addr = cfg.error_addr;
        end
        if (vip_cfg.agent_cfg.is_active == UVM_PASSIVE &&
                (vip.agent.master_driver != null || vip.agent.slave_driver != null ||
                    vip.agent.sequencer != null))
            `uvm_error("AHB_TOPOLOGY", "Passive VIP constructed an active path")
        if (!vip_cfg.agent_cfg.checks_enable && vip.agent.protocol_checker != null)
            `uvm_error("AHB_TOPOLOGY", "Disabled checker was constructed")
    endfunction
endclass
