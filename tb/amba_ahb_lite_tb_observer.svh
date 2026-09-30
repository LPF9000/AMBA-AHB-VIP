class amba_ahb_lite_tb_timeout_policy extends uvm_report_catcher;
    `uvm_object_utils(amba_ahb_lite_tb_timeout_policy)
    amba_ahb_lite_tb_cfg cfg;
    function new(string name = "amba_ahb_lite_tb_timeout_policy");
        super.new(name);
    endfunction
    function action_e catch();
        if (get_severity() == UVM_ERROR && get_id() == "AHB_TIMEOUT") begin
            cfg.timeout_reports++;
            return CAUGHT;
        end
        if (get_severity() == UVM_ERROR && get_id() == "AHB_ITEM" && cfg.expected_rejects != 0) begin
            cfg.reject_reports++;
            return CAUGHT;
        end
        return THROW;
    endfunction
endclass

`uvm_analysis_imp_decl(_tb_abort)
`uvm_analysis_imp_decl(_tb_reset)
`uvm_analysis_imp_decl(_tb_result)

class amba_ahb_lite_tb_observer extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_tb_observer)
    amba_ahb_lite_tb_cfg cfg;
    uvm_analysis_imp_tb_abort #(amba_ahb_lite_observed_item,
        amba_ahb_lite_tb_observer) aborted_export;
    uvm_analysis_imp_tb_reset #(amba_ahb_lite_reset_event,
        amba_ahb_lite_tb_observer) reset_export;
    uvm_analysis_imp_tb_result #(amba_ahb_lite_item,
        amba_ahb_lite_tb_observer) result_export;
    protected int unsigned completions;
    protected int unsigned aborts;
    protected int unsigned resets;
    protected int unsigned timeouts;
    protected int unsigned rejects;
    protected int unsigned retained_reads;
    protected int unsigned timeout_reports;

    function new(string name = "amba_ahb_lite_tb_observer", uvm_component parent = null);
        super.new(name, parent);
        aborted_export = new("aborted_export", this);
        reset_export = new("reset_export", this);
        result_export = new("result_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        amba_ahb_lite_tb_timeout_policy policy;
        super.build_phase(phase);
        if (cfg.expected_timeouts != 0 || cfg.expected_rejects != 0) begin
            policy = amba_ahb_lite_tb_timeout_policy::type_id::create("timeout_policy");
            policy.cfg = cfg;
            uvm_report_cb::add(null, policy);
        end
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        completions++;
        if ((cfg.reset_on_transfer || cfg.expected_timeouts != 0) &&
                !item.write && item.addr == 32'h100 && item.rdata !== '0)
            `uvm_error("AHB_REQUIREMENT", "Aborted write changed recovery readback")
        if (cfg.scenario == TB_RESET_RETAIN && !item.write && item.addr == 32'h104) begin
            if (retained_reads == 0 && item.rdata !== 32'h2468_1357)
                `uvm_error("AHB_REQUIREMENT", "Reset lost memory configured for retention")
            retained_reads++;
        end
        if (cfg.scenario inside {TB_WAIT, TB_SLAVE_WAIT, TB_SLAVE_SCRIPT, TB_LONG_WAIT}) begin
            if (item.wait_cycles != cfg.waits)
                `uvm_error("AHB_REQUIREMENT", "Observed wait count differs from the scenario policy")
        end
        if (item.resp == AHB_ERROR && (!item.error_wait_seen || !item.error_complete_seen))
            `uvm_error("AHB_REQUIREMENT", "ERROR lacks independently sampled response evidence")
    endfunction

    function void write_tb_abort(amba_ahb_lite_observed_item item);
        aborts++;
        if (item.addr !== 32'h100)
            `uvm_error("AHB_REQUIREMENT", "Reset/timeout aborted the wrong scenario transfer")
    endfunction

    function void write_tb_reset(amba_ahb_lite_reset_event item);
        resets++;
    endfunction

    function void write_tb_result(amba_ahb_lite_item item);
        if (item.timed_out)
            timeouts++;
        if (item.protocol_reject)
            rejects++;
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
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
        `uvm_info("AHB_REQUIREMENT", $sformatf(
            "completed=%0d aborted=%0d resets=%0d timeouts=%0d rejects=%0d",
            completions, aborts, resets, timeouts, rejects), UVM_LOW)
    endfunction
endclass
