class amba_ahb_lite_reuse_test extends amba_ahb_lite_base_test;
    `uvm_component_utils(amba_ahb_lite_reuse_test)

    function new(string name = "amba_ahb_lite_reuse_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void configure();
        cfg.scenario = TB_LANES;
        cfg.base_addr = tb_base_addr + ahb_burst_boundary_bytes;
    endfunction
endclass : amba_ahb_lite_reuse_test
