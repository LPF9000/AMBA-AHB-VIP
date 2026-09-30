`uvm_analysis_imp_decl(_stream_accepted)
`uvm_analysis_imp_decl(_stream_completed)
`uvm_analysis_imp_decl(_stream_aborted)
`uvm_analysis_imp_decl(_stream_reset)

class amba_ahb_lite_stream_scoreboard extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_stream_scoreboard)
    uvm_analysis_imp_stream_accepted #(amba_ahb_lite_observed_item,
        amba_ahb_lite_stream_scoreboard) accepted_export;
    uvm_analysis_imp_stream_completed #(amba_ahb_lite_observed_item,
        amba_ahb_lite_stream_scoreboard) item_export;
    uvm_analysis_imp_stream_aborted #(amba_ahb_lite_observed_item,
        amba_ahb_lite_stream_scoreboard) aborted_export;
    uvm_analysis_imp_stream_reset #(amba_ahb_lite_reset_event,
        amba_ahb_lite_stream_scoreboard) reset_export;
    protected amba_ahb_lite_observed_item pending_q[$];
    int unsigned accepted_count;
    int unsigned observed_count;
    int unsigned reset_count;
    int unsigned aborted_count;

    function new(string name = "amba_ahb_lite_stream_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        accepted_export = new("accepted_export", this);
        item_export = new("item_export", this);
        aborted_export = new("aborted_export", this);
        reset_export = new("reset_export", this);
    endfunction

    function void write_stream_accepted(amba_ahb_lite_observed_item item);
        amba_ahb_lite_observed_item snapshot;
        snapshot = amba_ahb_lite_observed_item::type_id::create("snapshot");
        snapshot.copy(item);
        pending_q.push_back(snapshot);
        accepted_count++;
    endfunction

    function void consume(amba_ahb_lite_observed_item item);
        amba_ahb_lite_observed_item accepted;
        if (pending_q.size() == 0) begin
            `uvm_error("AHB_STREAM", "Completion/abort has no accepted address phase")
            return;
        end
        accepted = pending_q.pop_front();
        if ({accepted.addr, accepted.write, accepted.size, accepted.trans,
             accepted.reset_generation} !==
                {item.addr, item.write, item.size, item.trans, item.reset_generation})
            `uvm_error("AHB_STREAM", "Accepted and terminal transfer identities differ")
    endfunction

    function void write_stream_completed(amba_ahb_lite_observed_item item);
        consume(item);
        if (!item.data_completed || !item.completed || item.reset_abort || item.timed_out)
            `uvm_error("AHB_STREAM", "Completed stream received a non-completion")
        observed_count++;
    endfunction

    function void write_stream_aborted(amba_ahb_lite_observed_item item);
        consume(item);
        if (item.completed || !(item.reset_abort ^ item.timed_out))
            `uvm_error("AHB_STREAM", "Abort must carry exactly one terminal cause")
        aborted_count++;
    endfunction

    function void write_stream_reset(amba_ahb_lite_reset_event item);
        reset_count++;
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (pending_q.size() != 0 || accepted_count != observed_count + aborted_count)
            `uvm_error("AHB_STREAM", "Accepted transfers are not fully accounted for")
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("AHB_STREAM", $sformatf(
            "accepted=%0d observed=%0d resets=%0d aborted=%0d pending=%0d",
            accepted_count, observed_count, reset_count, aborted_count, pending_q.size()), UVM_LOW)
    endfunction
endclass
