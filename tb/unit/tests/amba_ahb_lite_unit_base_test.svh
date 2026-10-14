class amba_ahb_lite_unit_base_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_unit_base_test)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_lite_tb_unit_checks unit_checks;

    function new(string name = "amba_ahb_lite_unit_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void configure();
        cfg.scenario = TB_CONFIG;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = amba_ahb_lite_tb_cfg::type_id::create("cfg");
        configure();
        unit_checks = amba_ahb_lite_tb_unit_checks::type_id::create("unit_checks", this);
        unit_checks.cfg = cfg;
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        unit_checks.done.wait_on();
        phase.drop_objection(this);
    endtask
endclass
