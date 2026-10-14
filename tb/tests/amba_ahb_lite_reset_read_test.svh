class amba_ahb_lite_reset_read_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reset_read_test)

    function new(string name = "amba_ahb_lite_reset_read_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_RESET_READ;
    endfunction
endclass
