class amba_ahb_lite_env_config extends uvm_object;
    `uvm_object_utils(amba_ahb_lite_env_config)

    amba_ahb_lite_agent_config agent_cfg;
    bit enable_stream_scoreboard = 1'b0;
    bit enable_predictor = 1'b1;
    bit enable_scoreboard = 1'b1;
    bit enable_coverage = 1'b0;

    function new(string name = "amba_ahb_lite_env_config");
        super.new(name);
    endfunction
endclass
