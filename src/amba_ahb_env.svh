class amba_ahb_env extends uvm_env;
    `uvm_component_utils(amba_ahb_env)

    amba_ahb_env_cfg env_cfg;
    amba_ahb_agent agent;
    amba_ahb_stream_scoreboard stream_scoreboard;
    amba_ahb_predictor predictor;
    amba_ahb_scoreboard scoreboard;
    amba_ahb_coverage coverage;
    // These are optional fanout points. Analysis ports, rather than mandatory
    // exports, allow a passive/topology-only environment to omit downstream
    // scoreboards without UVM connection-count errors.
    uvm_analysis_port #(amba_ahb_item) intent_ap;
    uvm_analysis_port #(amba_ahb_observed_item) observed_ap;
    uvm_analysis_port #(amba_ahb_reset_event) reset_ap;

    function new(string name = "amba_ahb_env", uvm_component parent = null);
        super.new(name, parent);
        intent_ap = new("intent_ap", this);
        observed_ap = new("observed_ap", this);
        reset_ap = new("reset_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_env_cfg)::get(this, "", "cfg", env_cfg) || env_cfg == null)
            `uvm_fatal("AHB_CFG", "Environment requires amba_ahb_env_cfg")
        if (env_cfg.agent_cfg == null)
            `uvm_fatal("AHB_CFG", "Environment config requires agent_cfg")
        uvm_config_db#(amba_ahb_agent_cfg)::set(this, "agent", "cfg", env_cfg.agent_cfg);
        agent = amba_ahb_agent::type_id::create("agent", this);
        if (env_cfg.enable_stream_scoreboard) begin
            stream_scoreboard = amba_ahb_stream_scoreboard::type_id::create(
                "stream_scoreboard", this);
        end
        if (env_cfg.enable_predictor && (env_cfg.external_intent ||
                ((env_cfg.agent_cfg.is_active == UVM_ACTIVE) &&
                    (env_cfg.agent_cfg.role == AHB_MASTER))))
            begin
                uvm_config_db#(amba_ahb_agent_cfg)::set(this, "predictor", "cfg", env_cfg.agent_cfg);
                predictor = amba_ahb_predictor::type_id::create("predictor", this);
            end
        if (env_cfg.enable_scoreboard && predictor == null)
            `uvm_fatal("AHB_CFG", "Semantic scoreboard requires an intent predictor")
        if (env_cfg.enable_scoreboard)
            begin
                uvm_config_db#(amba_ahb_agent_cfg)::set(this, "scoreboard", "cfg", env_cfg.agent_cfg);
                scoreboard = amba_ahb_scoreboard::type_id::create("scoreboard", this);
            end
        if (env_cfg.enable_coverage)
            coverage = amba_ahb_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.item_ap.connect(observed_ap);
        agent.monitor.reset_ap.connect(reset_ap);
        if (stream_scoreboard != null) begin
            agent.monitor.accepted_ap.connect(stream_scoreboard.accepted_export);
            agent.monitor.aborted_ap.connect(stream_scoreboard.aborted_export);
            observed_ap.connect(stream_scoreboard.item_export);
            reset_ap.connect(stream_scoreboard.reset_export);
        end
        if (predictor != null) begin
            intent_ap.connect(predictor.intent_export);
            agent.monitor.aborted_ap.connect(predictor.aborted_export);
            if (agent.master_driver != null) begin
                agent.master_driver.request_ap.connect(intent_ap);
                agent.master_driver.result_ap.connect(predictor.result_export);
            end
            agent.monitor.item_ap.connect(predictor.actual_export);
            agent.monitor.reset_ap.connect(predictor.reset_export);
        end
        if (scoreboard != null) begin
            agent.monitor.item_ap.connect(scoreboard.actual_export);
            if (predictor != null)
                predictor.expected_ap.connect(scoreboard.expected_export);
            agent.monitor.reset_ap.connect(scoreboard.reset_export);
        end
        if (coverage != null) begin
            agent.monitor.item_ap.connect(coverage.analysis_export);
            agent.monitor.cycle_ap.connect(coverage.cycle_export);
            agent.monitor.reset_ap.connect(coverage.reset_export);
            agent.monitor.aborted_ap.connect(coverage.aborted_export);
        end
    endfunction
endclass
