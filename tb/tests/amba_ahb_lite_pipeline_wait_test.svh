class amba_ahb_lite_pipeline_wait_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_pipeline_wait_test)

    function new(string name = "amba_ahb_lite_pipeline_wait_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_PIPELINE_WAIT;
    endfunction
endclass
