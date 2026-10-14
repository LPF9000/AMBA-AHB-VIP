class amba_ahb_lite_tb_response_seq extends uvm_sequence #(amba_ahb_item);
    `uvm_object_utils(amba_ahb_lite_tb_response_seq)

    function new(string name = "amba_ahb_lite_tb_response_seq");
        super.new(name);
    endfunction

    task body();
        repeat (tb_pipeline_transfers) begin
            amba_ahb_item item;
            item = amba_ahb_item::type_id::create("response");
            start_item(item);
            item.wait_cycles = tb_default_waits;
            finish_item(item);
        end
    endtask
endclass
