`uvm_analysis_imp_decl(_tb_abort)
`uvm_analysis_imp_decl(_tb_reset)
`uvm_analysis_imp_decl(_tb_result)
`uvm_analysis_imp_decl(_tb_intent)

class amba_ahb_lite_tb_observer extends uvm_subscriber #(amba_ahb_observed_item);
    `uvm_component_utils(amba_ahb_lite_tb_observer)
    amba_ahb_lite_tb_cfg cfg;
    uvm_analysis_imp_tb_abort #(amba_ahb_observed_item,
        amba_ahb_lite_tb_observer) aborted_export;
    uvm_analysis_imp_tb_reset #(amba_ahb_reset_event,
        amba_ahb_lite_tb_observer) reset_export;
    uvm_analysis_imp_tb_result #(amba_ahb_item,
        amba_ahb_lite_tb_observer) result_export;
    uvm_analysis_imp_tb_intent #(amba_ahb_item,
        amba_ahb_lite_tb_observer) intent_export;
    protected int unsigned completions;
    protected int unsigned aborts;
    protected int unsigned resets;
    protected int unsigned timeouts;
    protected int unsigned rejects;
    protected int unsigned idle_results;
    protected int unsigned retained_reads;
    protected int unsigned timing_reads;
    protected int unsigned timing_results;
    protected int unsigned timeout_reports;
    protected amba_ahb_lite_tb_timeout_policy report_policy;
    protected uvm_report_object report_source;

    function new(string name = "amba_ahb_lite_tb_observer", uvm_component parent = null);
        super.new(name, parent);
        aborted_export = new("aborted_export", this);
        reset_export = new("reset_export", this);
        result_export = new("result_export", this);
        intent_export = new("intent_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (cfg == null)
            `uvm_fatal("AHB_CFG", "Observer requires typed testbench configuration")
        if (cfg.expected_timeouts != 0 || cfg.expected_rejects != 0) begin
            report_policy = amba_ahb_lite_tb_timeout_policy::type_id::create("timeout_policy");
            report_policy.cfg = cfg;
        end
    endfunction

    function void bind_expected_reports(uvm_report_object source);
        if (report_policy == null)
            return;
        if (source == null || report_source != null)
            `uvm_fatal("AHB_CFG", "Expected driver reports require one reporting source")
        report_source = source;
        uvm_report_cb::add(report_source, report_policy);
    endfunction

    function void write(amba_ahb_observed_item item);
        completions++;
        if ((cfg.scenario inside {TB_RESPONSE_LATE, TB_RESPONSE_EDGE}) && !item.write) begin
            timing_reads++;
            if (item.addr !== cfg.base_addr || item.rdata !== tb_timing_data ||
                    item.resp !== AHB_OKAY || item.wait_cycles != 0 ||
                    !item.completed || item.reset_abort || item.timed_out)
                `uvm_error("AHB_TIMING", "Monitor did not preserve the rising-edge read response")
        end
        if ((cfg.reset_on_transfer || cfg.expected_timeouts != 0) &&
                !item.write && item.addr == cfg.base_addr && item.rdata !== '0)
            `uvm_error("AHB_REQUIREMENT", "Aborted write changed recovery readback")
        if (cfg.scenario == TB_RESET_RETAIN && !item.write && item.addr == (cfg.base_addr + ahb_data_bytes)) begin
            if (retained_reads == 0 && item.rdata !== cfg.retained_data)
                `uvm_error("AHB_REQUIREMENT", "Reset lost memory configured for retention")
            retained_reads++;
        end
        if (cfg.scenario inside {TB_WAIT, TB_SLAVE_WAIT, TB_SLAVE_SCRIPT, TB_LONG_WAIT, TB_READY}) begin
            if (item.wait_cycles != cfg.waits)
                `uvm_error("AHB_REQUIREMENT", "Observed wait count differs from the scenario policy")
        end
        if (item.resp == AHB_ERROR && (!item.error_wait_seen || !item.error_complete_seen))
            `uvm_error("AHB_REQUIREMENT", "ERROR lacks independently sampled response evidence")
    endfunction

    function void write_tb_abort(amba_ahb_observed_item item);
        aborts++;
        if (item.addr !== cfg.base_addr)
            `uvm_error("AHB_REQUIREMENT", "Reset/timeout aborted the wrong scenario transfer")
    endfunction

    function void write_tb_reset(amba_ahb_reset_event item);
        resets++;
    endfunction

    function void write_tb_result(amba_ahb_item item);
        if ((cfg.scenario inside {TB_RESPONSE_LATE, TB_RESPONSE_EDGE}) && !item.write) begin
            timing_results++;
            if (item.addr !== cfg.base_addr || item.rdata !== tb_timing_data ||
                    item.resp !== AHB_OKAY || item.wait_cycles != 0 ||
                    !item.address_accepted || !item.completed || item.reset_abort ||
                    item.timed_out || item.protocol_reject)
                `uvm_error("AHB_TIMING", "Master did not preserve the rising-edge read response")
        end
        if (item.trans == AHB_IDLE) begin
            idle_results++;
            if (item.address_accepted || item.completed || item.protocol_reject ||
                    item.reset_abort || item.timed_out || item.resp != AHB_OKAY)
                `uvm_error("AHB_REQUIREMENT", "IDLE result carries transfer or failure status")
        end
        if (item.timed_out)
            timeouts++;
        if (item.protocol_reject)
            rejects++;
    endfunction

    function void write_tb_intent(amba_ahb_item item);
        if (item.trans inside {AHB_IDLE, AHB_BUSY})
            `uvm_error("AHB_REQUIREMENT", "Non-transfer was published as memory intent")
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if ((cfg.scenario inside {TB_RESPONSE_LATE, TB_RESPONSE_EDGE}) &&
                (timing_reads != 1 || timing_results != 1))
            `uvm_error("AHB_TIMING", "Timing scenario requires one monitor read and one master result")
        if (report_policy != null && report_source == null)
            `uvm_error("AHB_REQUIREMENT", "Expected driver report source was not bound")
        if (idle_results != cfg.expected_idle_results)
            `uvm_error("AHB_REQUIREMENT", "IDLE result count differs from scenario intent")
        if (completions != cfg.expected_completions || aborts != cfg.expected_aborts ||
                resets != cfg.expected_resets || timeouts != cfg.expected_timeouts ||
                rejects != cfg.expected_rejects || cfg.timeout_reports != cfg.expected_timeouts ||
                cfg.reject_reports != cfg.expected_rejects)
            `uvm_error("AHB_REQUIREMENT", $sformatf(
                "Counts actual/expected: completed=%0d/%0d abort=%0d/%0d reset=%0d/%0d timeout=%0d/%0d reject=%0d/%0d",
                completions, cfg.expected_completions, aborts, cfg.expected_aborts,
                resets, cfg.expected_resets, timeouts, cfg.expected_timeouts,
                rejects, cfg.expected_rejects))
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("AHB_REQUIREMENT", $sformatf(
            "completed=%0d aborted=%0d resets=%0d timeouts=%0d rejects=%0d",
            completions, aborts, resets, timeouts, rejects), UVM_LOW)
    endfunction

    function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        if (report_policy != null && report_source != null)
            uvm_report_cb::delete(report_source, report_policy);
    endfunction
endclass
