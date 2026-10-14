class amba_ahb_lite_checks_disabled_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_checks_disabled_test)

    function new(string name = "amba_ahb_lite_checks_disabled_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_CHECKS_DISABLED;
    endfunction
endclass
