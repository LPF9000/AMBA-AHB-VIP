class amba_ahb_lite_idle_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_idle_test)

    function new(string name = "amba_ahb_lite_idle_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_IDLE;
    endfunction
endclass : amba_ahb_lite_idle_test
