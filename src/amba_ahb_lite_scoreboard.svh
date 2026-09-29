`uvm_analysis_imp_decl(_actual)
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_scoreboard_reset)

class amba_ahb_lite_scoreboard extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_scoreboard)

    uvm_analysis_imp_actual #(amba_ahb_lite_observed_item, amba_ahb_lite_scoreboard) actual_export;
    uvm_analysis_imp_expected #(amba_ahb_lite_observed_item, amba_ahb_lite_scoreboard) expected_export;
    uvm_analysis_imp_scoreboard_reset #(amba_ahb_lite_reset_event,
                                                                            amba_ahb_lite_scoreboard) reset_export;
    protected amba_ahb_lite_observed_item actual_q[$];
    protected amba_ahb_lite_observed_item expected_q[$];
    int unsigned match_count;
    int unsigned mismatches;
    int unsigned reset_generation;
    int unsigned reset_dropped_actual;
    int unsigned reset_dropped_expected;
    amba_ahb_lite_agent_config cfg;

    function new(string name = "amba_ahb_lite_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        actual_export = new("actual_export", this);
        expected_export = new("expected_export", this);
        reset_export = new("reset_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg));
    endfunction

    function void write_actual(amba_ahb_lite_observed_item item);
        actual_q.push_back(item);
        compare_available();
    endfunction

    function void write_expected(amba_ahb_lite_observed_item item);
        expected_q.push_back(item);
        compare_available();
    endfunction

    function void compare_available();
        amba_ahb_lite_observed_item actual;
        amba_ahb_lite_observed_item expected;
        while ((actual_q.size() != 0) && (expected_q.size() != 0)) begin
            actual = actual_q.pop_front();
            expected = expected_q.pop_front();
            if ((actual.reset_generation != expected.reset_generation) ||
                    (actual.addr !== expected.addr) || (actual.write !== expected.write) ||
                    (actual.trans !== expected.trans) || (actual.size !== expected.size) ||
                    (actual.burst !== expected.burst) || (actual.prot !== expected.prot) ||
                    (actual.mastlock !== expected.mastlock) ||
                    (actual.write && (actual.wdata !== expected.wdata)) ||
                    (actual.resp !== expected.resp) ||
                    (!actual.write && (actual.rdata !== expected.rdata)) ||
                    (actual.completed !== expected.completed) ||
                    (actual.reset_abort !== expected.reset_abort) ||
                    (actual.timed_out !== expected.timed_out) ||
                    (actual.protocol_reject !== expected.protocol_reject) ||
                    (actual.error_wait_seen !== expected.error_wait_seen) ||
                    (actual.error_complete_seen !== expected.error_complete_seen) ||
                    ((expected.wait_cycles != 0) &&
                      (actual.wait_cycles !== expected.wait_cycles))) begin
                mismatches++;
                `uvm_error("AHB_SCOREBOARD", $sformatf("Actual/expected mismatch\nactual: %s\nexpected: %s",
                    actual.convert2string(), expected.convert2string()))
            end else begin
                match_count++;
            end
        end
    endfunction

    function void write_scoreboard_reset(amba_ahb_lite_reset_event event_item);
        if ((cfg == null) || cfg.flush_on_reset) begin
            reset_dropped_actual += actual_q.size();
            reset_dropped_expected += expected_q.size();
            actual_q.delete();
            expected_q.delete();
        end
        reset_generation = event_item.reset_generation;
    endfunction

    function void check_phase(uvm_phase phase);
        compare_available();
        if ((actual_q.size() != 0) || (expected_q.size() != 0))
            `uvm_error("AHB_SCOREBOARD", $sformatf("Unpaired streams at check: actual=%0d expected=%0d",
                actual_q.size(), expected_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("AHB_SCOREBOARD", $sformatf(
            "matches=%0d mismatches=%0d reset_generation=%0d reset_dropped_actual=%0d reset_dropped_expected=%0d",
            match_count, mismatches, reset_generation, reset_dropped_actual,
            reset_dropped_expected), UVM_LOW)
    endfunction
endclass
