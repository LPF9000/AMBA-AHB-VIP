class amba_ahb_lite_config_test extends amba_ahb_lite_unit_base_test;
    `uvm_component_utils(amba_ahb_lite_config_test)

    function new(string name = "amba_ahb_lite_config_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_CONFIG;
    endfunction
endclass
