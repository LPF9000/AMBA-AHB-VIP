`uvm_analysis_imp_decl(_intent)
`uvm_analysis_imp_decl(_predictor_actual)
`uvm_analysis_imp_decl(_predictor_reset)
`uvm_analysis_imp_decl(_predictor_abort)
`uvm_analysis_imp_decl(_predictor_result)

class amba_ahb_predictor extends uvm_component;
    `uvm_component_utils(amba_ahb_predictor)

    uvm_analysis_imp_intent #(amba_ahb_item, amba_ahb_predictor) intent_export;
    uvm_analysis_imp_predictor_actual #(amba_ahb_observed_item,
        amba_ahb_predictor) actual_export;
    uvm_analysis_imp_predictor_reset #(amba_ahb_reset_event,
        amba_ahb_predictor) reset_export;
    uvm_analysis_imp_predictor_abort #(amba_ahb_observed_item,
        amba_ahb_predictor) aborted_export;
    uvm_analysis_imp_predictor_result #(amba_ahb_item,
        amba_ahb_predictor) result_export;
    uvm_analysis_port #(amba_ahb_observed_item) expected_ap;
    bit [ahb_byte_bits-1:0] mem [longint unsigned];
    amba_ahb_item pending_intents[$];
    int unsigned reset_generation;
    amba_ahb_agent_cfg cfg;

    function new(string name = "amba_ahb_predictor", uvm_component parent = null);
        super.new(name, parent);
        intent_export = new("intent_export", this);
        actual_export = new("actual_export", this);
        reset_export = new("reset_export", this);
        expected_ap = new("expected_ap", this);
        aborted_export = new("aborted_export", this);
        result_export = new("result_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_agent_cfg)::get(this, "", "cfg", cfg) || cfg == null)
            `uvm_fatal("AHB_CFG", "Predictor requires typed configuration")
    endfunction

    function void write_intent(amba_ahb_item intent);
        amba_ahb_item queued_intent;
        if (intent.trans inside {AHB_IDLE, AHB_BUSY})
            return;
        // Intent is only a request.  Queue it until the monitor reports the
        // matching completed data phase; this prevents reset, timeout, and ERROR
        // requests from mutating the independent reference model.
        queued_intent = amba_ahb_item::type_id::create("queued_intent");
        queued_intent.copy(intent);
        pending_intents.push_back(queued_intent);
    endfunction

    function void write_predictor_actual(amba_ahb_observed_item actual);
        amba_ahb_item intent;
        amba_ahb_observed_item expected;
        int unsigned nbytes;
        if (pending_intents.size() == 0) begin
            `uvm_error("AHB_PREDICTOR", "Observed transfer has no queued master intent")
            return;
        end
        intent = pending_intents.pop_front();
        expected = amba_ahb_observed_item::type_id::create("expected");
        expected.copy(intent);
        expected.reset_generation = actual.reset_generation;
        expected.address_accepted = 1'b1;
        expected.data_completed = 1'b1;
        expected.completed = 1'b1;
        expected.reset_abort = 1'b0;
        expected.timed_out = 1'b0;
        expected.protocol_reject = 1'b0;
        // Preserve sampled response-phase evidence across the predictor boundary.
        // These markers are semantic protocol metadata, unlike timestamps.
        // Timing evidence is checked independently by the raw cycle checker.
        expected.resp = (cfg != null && cfg.response_policy != null) ?
            cfg.response_policy.predict_response(intent) : AHB_OKAY;
        expected.rdata = '0;
        nbytes = 0;
        if (!$isunknown({intent.addr, intent.write, intent.trans, intent.size,
            intent.burst, intent.prot, intent.wdata}))
            nbytes = ahb_size_bytes(intent.size);
        if (nbytes < ahb_data_bytes && nbytes != 0)
            expected.wdata &= (ahb_data_t'(1) << (nbytes * ahb_byte_bits)) - 1;
        if (actual.completed && (actual.resp == AHB_OKAY) &&
                (expected.resp == AHB_OKAY)) begin
            if (intent.write) begin
                for (int unsigned i = 0; i < nbytes; i++)
                    mem[$unsigned(longint'(intent.addr)) + $unsigned(longint'(i))] = intent.wdata[i* ahb_byte_bits +: ahb_byte_bits];
            end else begin
                for (int unsigned i = 0; i < nbytes; i++)
                    expected.rdata[i* ahb_byte_bits +: ahb_byte_bits] = mem.exists($unsigned(longint'(intent.addr)) + $unsigned(longint'(i))) ?
                        mem[$unsigned(longint'(intent.addr)) + $unsigned(longint'(i))] : '0;
            end
        end
        expected_ap.write(expected);
    endfunction

    function void discard_intent(amba_ahb_item terminal);
        amba_ahb_item intent;
        if (pending_intents.size() == 0) begin
            `uvm_error("AHB_PREDICTOR", "Abort has no queued intent")
            return;
        end
        intent = pending_intents.pop_front();
        if (intent.addr !== terminal.addr || intent.write !== terminal.write)
            `uvm_error("AHB_PREDICTOR", "Aborted intent identity differs")
    endfunction

    function void write_predictor_abort(amba_ahb_observed_item item);
        discard_intent(item);
    endfunction

    function void write_predictor_result(amba_ahb_item item);
        if (item.trans inside {AHB_IDLE, AHB_BUSY})
            return;
        if (item.timed_out && !item.address_accepted)
            discard_intent(item);
        else if (item.reset_abort && !item.address_accepted && pending_intents.size() != 0)
            discard_intent(item);
    endfunction

    function void write_predictor_reset(amba_ahb_reset_event event_item);
        if ((cfg == null) || cfg.flush_on_reset)
            mem.delete();
        pending_intents.delete();
        reset_generation = event_item.reset_generation;
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (pending_intents.size() != 0)
            `uvm_error("AHB_PREDICTOR", $sformatf(
                "Unmatched master intents remain at end of test: %0d",
                pending_intents.size()))
    endfunction
endclass
