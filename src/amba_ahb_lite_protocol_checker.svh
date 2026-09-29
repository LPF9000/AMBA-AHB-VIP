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
    uvm_analysis_imp_checker_reset #(amba_ahb_lite_reset_event,
                                                                      amba_ahb_lite_protocol_checker) reset_export;
    bit burst_open;
    ahb_hburst_e burst_kind;
    int unsigned burst_count;
    bit [31:0] previous_addr;
    ahb_hsize_e previous_size;

    function new(string name = "amba_ahb_lite_protocol_checker", uvm_component parent = null);
        super.new(name, parent);
        violation_ap = new("violation_ap", this);
        reset_export = new("reset_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Protocol checker requires agent config")
    endfunction

    function void violation(string message, amba_ahb_lite_observed_item item);
        amba_ahb_lite_protocol_violation v;
        v = amba_ahb_lite_protocol_violation::type_id::create("violation");
        v.message = message;
        v.reset_generation = item.reset_generation;
        v.timestamp = $time;
        violation_ap.write(v);
        uvm_report(cfg.protocol_severity, "AHB_PROTOCOL", message);
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        int unsigned bytes;
        bit controls_unknown;
        controls_unknown = $isunknown({item.trans, item.size, item.burst});
        bytes = 0;
        if ($isunknown({item.addr, item.write, item.trans, item.size,
                                        item.burst, item.prot, item.wdata, item.resp}) ||
                (!item.write && $isunknown(item.rdata)))
            violation("Unknown value observed in completed AHB transfer", item);
        if (controls_unknown) begin
            // Preserve the raw unknown diagnostic above and do not perform helper
            // arithmetic on X/Z control values.
        end else begin
            bytes = ahb_size_bytes(item.size);
            if (!ahb_size_supported(item.size, cfg.data_width))
                violation("HSIZE exceeds configured data bus width", item);
            else if ((item.addr & (bytes - 1)) != 0)
                violation($sformatf("Unaligned address 0x%08x for %0d-byte transfer", item.addr, bytes), item);
        end

        if (!controls_unknown && (item.trans == AHB_NONSEQ)) begin
            if (burst_open && (ahb_burst_length(burst_kind) != 0) &&
                    (burst_count != ahb_burst_length(burst_kind)))
                violation("Fixed-length burst terminated before its required beat count", item);
            burst_open = (item.burst != AHB_SINGLE);
            burst_kind = item.burst;
            burst_count = 1;
            previous_addr = item.addr;
            previous_size = item.size;
        end else if (!controls_unknown && (item.trans == AHB_SEQ)) begin
            if (!burst_open)
                violation("SEQ transfer observed without an open burst", item);
            burst_count++;
            if ((ahb_burst_length(burst_kind) != 0) &&
                    (burst_count > ahb_burst_length(burst_kind)))
                violation("Fixed-length burst contains too many beats", item);
            begin
                longint unsigned expected_addr;
                longint unsigned boundary;
                longint unsigned base;
                expected_addr = longint'(previous_addr) + longint'(ahb_size_bytes(previous_size));
                if (ahb_is_wrapping(burst_kind)) begin
                    boundary = ahb_burst_length(burst_kind) * ahb_size_bytes(previous_size);
                    base = (longint'(previous_addr) / boundary) * boundary;
                    if (expected_addr >= base + boundary)
                        expected_addr = base;
                end
                if (item.addr !== expected_addr[31:0])
                    violation($sformatf("Unexpected burst address 0x%08x, expected 0x%08x",
                                                            item.addr, expected_addr[31:0]), item);
            end
            previous_addr = item.addr;
            previous_size = item.size;
        end
        if ((item.resp == AHB_ERROR) && !item.completed)
            violation("ERROR response was published without a completed data phase", item);
        if ((item.resp == AHB_ERROR) && !item.error_wait_seen)
            violation("ERROR completion lacked the required preceding ERROR wait cycle", item);
        if ((item.resp == AHB_ERROR) && !item.error_complete_seen)
            violation("ERROR response was not sampled on a completing response cycle", item);
        if (!controls_unknown && (item.burst == AHB_SINGLE))
            burst_open = 1'b0;
    endfunction

    function void write_checker_reset(amba_ahb_lite_reset_event event_item);
        burst_open = 1'b0;
        burst_count = 0;
    endfunction

    function void check_phase(uvm_phase phase);
        if (burst_open && (ahb_burst_length(burst_kind) != 0) &&
                (burst_count != ahb_burst_length(burst_kind))) begin
            uvm_report(cfg.protocol_severity, "AHB_PROTOCOL",
                "Fixed-length burst ended before its required beat count");
        end
    endfunction
endclass
