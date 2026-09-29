class amba_ahb_lite_env extends uvm_env;
    `uvm_component_utils(amba_ahb_lite_env)

    amba_ahb_lite_env_config env_cfg;
    amba_ahb_lite_agent agent;
    amba_ahb_lite_stream_scoreboard stream_scoreboard;
    amba_ahb_lite_predictor predictor;
    amba_ahb_lite_scoreboard scoreboard;
    amba_ahb_lite_coverage coverage;
    // These are optional fanout points. Analysis ports, rather than mandatory
    // exports, allow a passive/topology-only environment to omit downstream
    // scoreboards without UVM connection-count errors.
    uvm_analysis_port #(amba_ahb_lite_observed_item) observed_export;
    uvm_analysis_port #(amba_ahb_lite_reset_event) reset_export;

    function new(string name = "amba_ahb_lite_env", uvm_component parent = null);
        super.new(name, parent);
        observed_export = new("observed_export", this);
        reset_export = new("reset_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_env_config)::get(this, "", "cfg", env_cfg))
            `uvm_fatal("AHB_CFG", "Environment requires amba_ahb_lite_env_config")
        if (env_cfg.agent_cfg == null)
            `uvm_fatal("AHB_CFG", "Environment config requires agent_cfg")
        uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "agent", "cfg", env_cfg.agent_cfg);
        agent = amba_ahb_lite_agent::type_id::create("agent", this);
        if (env_cfg.enable_stream_scoreboard) begin
            stream_scoreboard = amba_ahb_lite_stream_scoreboard::type_id::create(
                "stream_scoreboard", this);
        end
        if (env_cfg.enable_predictor &&
                (env_cfg.agent_cfg.is_active == UVM_ACTIVE) &&
                (env_cfg.agent_cfg.role == AHB_MASTER))
            begin
                uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "predictor", "cfg", env_cfg.agent_cfg);
                predictor = amba_ahb_lite_predictor::type_id::create("predictor", this);
            end
        if (env_cfg.enable_scoreboard)
            begin
                uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "scoreboard", "cfg", env_cfg.agent_cfg);
                scoreboard = amba_ahb_lite_scoreboard::type_id::create("scoreboard", this);
            end
        if (env_cfg.enable_coverage)
            coverage = amba_ahb_lite_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.item_ap.connect(observed_export);
        agent.monitor.reset_ap.connect(reset_export);
        if (stream_scoreboard != null) begin
            observed_export.connect(stream_scoreboard.item_export);
            reset_export.connect(stream_scoreboard.reset_export);
        end
        if ((predictor != null) && (env_cfg.agent_cfg.role == AHB_MASTER)) begin
            agent.master_driver.request_ap.connect(predictor.intent_export);
            agent.monitor.item_ap.connect(predictor.actual_export);
            agent.monitor.reset_ap.connect(predictor.reset_export);
        end
        if (scoreboard != null) begin
            agent.monitor.item_ap.connect(scoreboard.actual_export);
            if (predictor != null)
                predictor.expected_ap.connect(scoreboard.expected_export);
            agent.monitor.reset_ap.connect(scoreboard.reset_export);
        end
        if (coverage != null)
            agent.monitor.item_ap.connect(coverage.analysis_export);
    endfunction
endclass
