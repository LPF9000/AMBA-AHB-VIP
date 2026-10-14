class amba_ahb_lite_reset_error_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_error_test)

    function new(string name = "amba_ahb_lite_reset_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_ERROR;
    endfunction
endclass
