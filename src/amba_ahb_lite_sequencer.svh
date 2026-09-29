class amba_ahb_lite_sequencer extends uvm_sequencer #(amba_ahb_lite_item);
    `uvm_component_utils(amba_ahb_lite_sequencer)

    function new(string name = "amba_ahb_lite_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
