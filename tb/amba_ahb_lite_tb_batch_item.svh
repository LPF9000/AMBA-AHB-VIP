class amba_ahb_lite_tb_batch_item extends uvm_sequence_item;
    `uvm_object_utils(amba_ahb_lite_tb_batch_item)
    amba_ahb_item transfers[$];

    function new(string name = "amba_ahb_lite_tb_batch_item");
        super.new(name);
    endfunction
endclass
