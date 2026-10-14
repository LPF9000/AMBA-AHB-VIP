class amba_ahb_lite_reset_smoke_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_smoke_test)

    function new(string name = "amba_ahb_lite_reset_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_WRITE;
    endfunction
endclass
