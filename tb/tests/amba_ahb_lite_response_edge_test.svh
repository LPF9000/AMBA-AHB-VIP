class amba_ahb_lite_response_edge_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_response_edge_test)

    function new(string name = "amba_ahb_lite_response_edge_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESPONSE_EDGE;
    endfunction
endclass
