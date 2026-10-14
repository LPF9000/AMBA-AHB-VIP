class amba_ahb_lite_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(amba_ahb_lite_virtual_sequencer)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_sequencer m_sqr;
    amba_ahb_sequencer slave_sqr;
    uvm_sequencer #(amba_ahb_lite_tb_batch_item) source_sqr;

    function new(string name = "amba_ahb_lite_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
