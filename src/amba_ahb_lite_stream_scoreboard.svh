`uvm_analysis_imp_decl(_ahb_item)
`uvm_analysis_imp_decl(_ahb_reset)

class amba_ahb_lite_stream_scoreboard extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_stream_scoreboard)

    uvm_analysis_imp_ahb_item #(amba_ahb_lite_observed_item,
                                                            amba_ahb_lite_stream_scoreboard) item_export;
    uvm_analysis_imp_ahb_reset #(amba_ahb_lite_reset_event,
                                                              amba_ahb_lite_stream_scoreboard) reset_export;
    int unsigned observed_count;
    int unsigned reset_count;
    int unsigned aborted_count;

    function new(string name = "amba_ahb_lite_stream_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_export = new("item_export", this);
        reset_export = new("reset_export", this);
    endfunction

    function void write_ahb_item(amba_ahb_lite_observed_item item);
        if (!item.data_completed || !item.completed)
            `uvm_error("AHB_STREAM", "Scoreboard received an incomplete observed item")
        observed_count++;
    endfunction

    function void write_ahb_reset(amba_ahb_lite_reset_event event_item);
        reset_count++;
        if (event_item.pending_transfer_aborted)
            aborted_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("AHB_STREAM", $sformatf("observed=%0d resets=%0d aborted=%0d",
            observed_count, reset_count, aborted_count), UVM_LOW)
    endfunction
endclass
