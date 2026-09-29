class amba_ahb_lite_reset_event extends uvm_object;
    `uvm_object_utils(amba_ahb_lite_reset_event)
    int unsigned reset_generation;
    bit pending_transfer_aborted;

    function new(string name = "amba_ahb_lite_reset_event");
        super.new(name);
    endfunction
endclass
