`uvm_analysis_imp_decl(_checker_cycle)
`uvm_analysis_imp_decl(_checker_reset)

class amba_ahb_lite_protocol_violation extends uvm_object;
    `uvm_object_utils(amba_ahb_lite_protocol_violation)
    string message;
    int unsigned reset_generation;
    time timestamp;

    function new(string name = "amba_ahb_lite_protocol_violation");
        super.new(name);
    endfunction
endclass

class amba_ahb_lite_protocol_checker extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_protocol_checker)
    amba_ahb_lite_agent_config cfg;
    uvm_analysis_port #(amba_ahb_lite_protocol_violation) violation_ap;
    uvm_analysis_imp_checker_cycle #(amba_ahb_lite_cycle_item,
        amba_ahb_lite_protocol_checker) cycle_export;
    uvm_analysis_imp_checker_reset #(amba_ahb_lite_reset_event,
        amba_ahb_lite_protocol_checker) reset_export;
    protected amba_ahb_lite_cycle_item previous;
    protected amba_ahb_lite_cycle_item burst_start;
    protected logic [31:0] previous_addr;
    protected bit burst_open;
    protected int unsigned burst_count;
    protected bit error_termination_allowed;
    protected int unsigned violation_count;

    function new(string name = "amba_ahb_lite_protocol_checker", uvm_component parent = null);
        super.new(name, parent);
        violation_ap = new("violation_ap", this);
        cycle_export = new("cycle_export", this);
        reset_export = new("reset_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Protocol checker requires typed agent configuration")
    endfunction

    function void violation(string message);
        amba_ahb_lite_protocol_violation item;
        item = amba_ahb_lite_protocol_violation::type_id::create("violation");
        item.message = message;
        item.timestamp = $time;
        item.reset_generation = previous == null ? 0 : previous.reset_generation;
        violation_count++;
        violation_ap.write(item);
        uvm_report(cfg.protocol_severity, "AHB_PROTOCOL", message);
    endfunction

    function void finish_burst();
        if (burst_open && (ahb_burst_length(burst_start.burst) != 0) &&
                (burst_count != ahb_burst_length(burst_start.burst)) &&
                !error_termination_allowed)
            violation("Fixed-length burst ended before its required beat count");
        burst_open = 1'b0;
        error_termination_allowed = 1'b0;
    endfunction

    function void check_address(amba_ahb_lite_cycle_item sample);
        int unsigned bytes;
        logic [31:0] expected_addr;
        int unsigned boundary;
        if ($isunknown({sample.addr, sample.write, sample.trans, sample.size,
                sample.burst, sample.prot, sample.mastlock})) begin
            violation("Unknown accepted address/control value");
            return;
        end
        if (!ahb_size_supported(sample.size, cfg.data_width)) begin
            violation("HSIZE exceeds configured data bus width");
            return;
        end
        bytes = ahb_size_bytes(sample.size);
        if ((sample.addr % bytes) != 0)
            violation("Unaligned accepted transfer");
        if (sample.mastlock && !cfg.has_hmastlock)
            violation("HMASTLOCK used while disabled by configuration");
        if ((sample.burst != AHB_SINGLE) && !cfg.allow_bursts)
            violation("Burst observed while disabled by configuration");
        if (sample.trans == AHB_NONSEQ) begin
            finish_burst();
            burst_start = amba_ahb_lite_cycle_item::type_id::create("burst_start");
            burst_start.copy(sample);
            burst_open = (sample.burst != AHB_SINGLE);
            burst_count = 1;
        end else begin
            if (!burst_open) begin
                violation("SEQ observed without an open burst");
                return;
            end
            if ({sample.size, sample.burst, sample.write, sample.prot, sample.mastlock} !==
                    {burst_start.size, burst_start.burst, burst_start.write,
                     burst_start.prot, burst_start.mastlock})
                violation("Address/control attributes changed inside a burst");
            bytes = ahb_size_bytes(burst_start.size);
            expected_addr = previous_addr + bytes;
            if (ahb_is_wrapping(burst_start.burst)) begin
                boundary = ahb_burst_length(burst_start.burst) * bytes;
                expected_addr = (previous_addr / boundary) * boundary +
                    ((previous_addr + bytes) % boundary);
            end
            if (sample.addr !== expected_addr)
                violation("Incorrect burst address progression");
            if (sample.addr[31:10] != burst_start.addr[31:10])
                violation("Burst crosses the 1-KB boundary");
            burst_count++;
            if ((ahb_burst_length(burst_start.burst) != 0) &&
                    (burst_count > ahb_burst_length(burst_start.burst)))
                violation("Fixed-length burst has excess beats");
        end
        previous_addr = sample.addr;
    endfunction

    function void write_checker_cycle(amba_ahb_lite_cycle_item sample);
        if (!sample.reset_n) begin
            if (sample.trans !== AHB_IDLE)
                violation("Master must drive IDLE during reset");
            if (sample.readyout !== 1'b1)
                violation("Slave must drive HREADYOUT high during reset");
            previous = null;
            return;
        end
        if ($isunknown({sample.ready, sample.resp, sample.trans, sample.selected}))
            violation("Unknown handshake/control value");
        if (previous != null) begin
            if (previous.pending_data && !previous.ready && (previous.resp == AHB_ERROR)) begin
                if (!sample.ready || sample.resp != AHB_ERROR)
                    violation("ERROR wait must be followed immediately by completing ERROR");
            end else if (previous.pending_data && !previous.ready) begin
                // IDLE/BUSY may become an active address during a stall. Once an
                // active next address is presented, it remains stable until ready.
                if (previous.trans inside {AHB_NONSEQ, AHB_SEQ}) begin
                    if ({sample.addr, sample.write, sample.trans, sample.size,
                         sample.burst, sample.prot, sample.mastlock} !==
                            {previous.addr, previous.write, previous.trans, previous.size,
                             previous.burst, previous.prot, previous.mastlock})
                        violation("Address/control changed during a stalled active address phase");
                end
                if (previous.pending_write && sample.wdata !== previous.wdata)
                    violation("Write data changed during a stalled data phase");
            end
        end
        if (sample.pending_data && sample.resp == AHB_ERROR) begin
            if (sample.ready && ((previous == null) || previous.ready ||
                    previous.resp != AHB_ERROR))
                violation("Completing ERROR lacked its preceding ERROR wait cycle");
            error_termination_allowed = 1'b1;
        end
        if (sample.selected && sample.ready) begin
            if (sample.trans inside {AHB_NONSEQ, AHB_SEQ})
                check_address(sample);
            else if (sample.trans == AHB_IDLE)
                finish_burst();
            else if (sample.trans == AHB_BUSY) begin
                if (!cfg.allow_busy || !burst_open)
                    violation("BUSY observed outside an enabled open burst");
                else if ((ahb_burst_length(burst_start.burst) != 0) &&
                        burst_count >= ahb_burst_length(burst_start.burst))
                    violation("Fixed-length burst cannot end with BUSY");
                else begin
                    logic [31:0] expected_addr;
                    int unsigned bytes = ahb_size_bytes(burst_start.size);
                    int unsigned boundary = ahb_burst_length(burst_start.burst) * bytes;
                    expected_addr = previous_addr + bytes;
                    if (ahb_is_wrapping(burst_start.burst))
                        expected_addr = (previous_addr / boundary) * boundary +
                            ((previous_addr + bytes) % boundary);
                    if (sample.addr !== expected_addr ||
                            {sample.size, sample.burst, sample.write, sample.prot, sample.mastlock} !==
                            {burst_start.size, burst_start.burst, burst_start.write,
                             burst_start.prot, burst_start.mastlock})
                        violation("BUSY address/control does not describe the next burst beat");
                end
            end
        end
        previous = amba_ahb_lite_cycle_item::type_id::create("previous");
        previous.copy(sample);
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        if (!item.completed || !item.address_accepted || !item.data_completed)
            violation("Monitor published an incomplete transfer");
        if ((item.resp == AHB_ERROR) &&
                (!item.error_wait_seen || !item.error_complete_seen))
            violation("ERROR transfer lacks sampled two-cycle response evidence");
        if ($isunknown(item.write ? item.wdata : item.rdata))
            violation("Unknown active data lane at completion");
    endfunction

    function void write_checker_reset(amba_ahb_lite_reset_event item);
        previous = null;
        burst_open = 1'b0;
        burst_count = 0;
        error_termination_allowed = 1'b0;
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        finish_burst();
    endfunction
endclass
