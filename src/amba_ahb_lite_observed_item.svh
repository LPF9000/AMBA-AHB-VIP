class amba_ahb_lite_observed_item extends amba_ahb_lite_item;
    int unsigned reset_generation;
    bit data_completed;
    time address_time;
    time completion_time;

    `uvm_object_utils(amba_ahb_lite_observed_item)

    function new(string name = "amba_ahb_lite_observed_item");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        amba_ahb_lite_observed_item rhs_item;
        amba_ahb_lite_item rhs_base;
        if (!$cast(rhs_base, rhs))
            `uvm_fatal("AHB_COPY", "Observed item copied from an incompatible object")
        super.do_copy(rhs);
        // Expected items originate as base sequence intents.  Preserve the base
        // fields while safely defaulting observation-only metadata in that case;
        // observed-to-observed copies retain the complete correlation snapshot.
        if ($cast(rhs_item, rhs)) begin
            reset_generation = rhs_item.reset_generation;
            address_accepted = rhs_item.address_accepted;
            data_completed = rhs_item.data_completed;
            error_wait_seen = rhs_item.error_wait_seen;
            error_complete_seen = rhs_item.error_complete_seen;
            address_time = rhs_item.address_time;
            completion_time = rhs_item.completion_time;
        end else begin
            reset_generation = 0;
            address_accepted = 1'b0;
            data_completed = 1'b0;
            error_wait_seen = 1'b0;
            error_complete_seen = 1'b0;
            address_time = 0;
            completion_time = 0;
        end
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        amba_ahb_lite_observed_item rhs_item;
        if (!$cast(rhs_item, rhs))
            return 1'b0;
        return super.do_compare(rhs, comparer) &&
                      (reset_generation == rhs_item.reset_generation) &&
                      (address_accepted == rhs_item.address_accepted) &&
                      (data_completed == rhs_item.data_completed) &&
                      (error_wait_seen == rhs_item.error_wait_seen) &&
                      (error_complete_seen == rhs_item.error_complete_seen);
    endfunction
endclass
