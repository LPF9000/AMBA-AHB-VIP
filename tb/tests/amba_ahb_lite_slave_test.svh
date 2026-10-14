class amba_ahb_lite_slave_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_slave_test)

    function new(string name = "amba_ahb_lite_slave_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_SLAVE;
    endfunction
endclass
