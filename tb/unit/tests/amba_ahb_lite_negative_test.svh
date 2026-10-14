class amba_ahb_lite_negative_test extends amba_ahb_lite_unit_base_test;
    `uvm_component_utils(amba_ahb_lite_negative_test)

    function new(string name = "amba_ahb_lite_negative_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_NEGATIVE;
    endfunction
endclass
