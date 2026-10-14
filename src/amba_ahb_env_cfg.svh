class amba_ahb_env_cfg extends uvm_object;
    `uvm_object_utils(amba_ahb_env_cfg)

    amba_ahb_agent_cfg agent_cfg;
    bit enable_stream_scoreboard = 1'b1;
    bit external_intent = 1'b0;
    bit enable_predictor = 1'b1;
    bit enable_scoreboard = 1'b1;
    bit enable_coverage = 1'b0;

    function new(string name = "amba_ahb_env_cfg");
        super.new(name);
    endfunction
endclass
