// Report expectation policy belongs to a protocol_checker component, never a UVM test.
class amba_ahb_lite_tb_report_policy extends uvm_report_catcher;
    `uvm_object_utils(amba_ahb_lite_tb_report_policy)
    int unsigned expected[string];
    int unsigned caught[string];

    function new(string name = "amba_ahb_lite_tb_report_policy");
        super.new(name);
    endfunction

    function action_e catch();
        foreach (expected[key]) begin
            if (get_severity() == UVM_ERROR &&
                    uvm_is_match(key, {get_id(), ":", get_message()})) begin
                caught[key]++;
                return CAUGHT;
            end
        end
        return THROW;
    endfunction
endclass

class amba_ahb_lite_tb_unit_checks extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_tb_unit_checks)
    amba_ahb_lite_tb_cfg cfg;
    uvm_event done;
    amba_ahb_lite_agent_config agent_cfg;
    amba_ahb_lite_protocol_checker protocol_checker;
    amba_ahb_lite_scoreboard scoreboard;
    amba_ahb_lite_predictor predictor;
    amba_ahb_lite_stream_scoreboard stream;
    amba_ahb_lite_tb_report_policy report_policy;

    function new(string name = "amba_ahb_lite_tb_unit_checks", uvm_component parent = null);
        super.new(name, parent);
        done = new("done");
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        report_policy = amba_ahb_lite_tb_report_policy::type_id::create("report_policy");
        uvm_report_cb::add(null, report_policy);
        agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "protocol_checker", "cfg", agent_cfg);
        uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "predictor", "cfg", agent_cfg);
        uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "scoreboard", "cfg", agent_cfg);
        protocol_checker = amba_ahb_lite_protocol_checker::type_id::create("protocol_checker", this);
        scoreboard = amba_ahb_lite_scoreboard::type_id::create("scoreboard", this);
        predictor = amba_ahb_lite_predictor::type_id::create("predictor", this);
        stream = amba_ahb_lite_stream_scoreboard::type_id::create("stream", this);
    endfunction

    function amba_ahb_lite_cycle_item cycle(logic [31:0] addr = 32'h100);
        amba_ahb_lite_cycle_item item;
        item = amba_ahb_lite_cycle_item::type_id::create("cycle");
        item.reset_n = 1'b1;
        item.addr = addr;
        item.selected = 1'b1;
        item.ready = 1'b1;
        item.readyout = 1'b1;
        item.trans = AHB_NONSEQ;
        item.size = AHB_WORD;
        item.burst = AHB_SINGLE;
        item.resp = AHB_OKAY;
        return item;
    endfunction

    function amba_ahb_lite_observed_item observation(logic [31:0] data = '0);
        amba_ahb_lite_observed_item item;
        item = amba_ahb_lite_observed_item::type_id::create("observation");
        item.addr = 32'h100;
        item.completed = 1'b1;
        item.address_accepted = 1'b1;
        item.data_completed = 1'b1;
        item.rdata = data;
        return item;
    endfunction

    function void reset_checker();
        amba_ahb_lite_reset_event item;
        item = amba_ahb_lite_reset_event::type_id::create("reset_item");
        protocol_checker.write_checker_reset(item);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_cycle_item sample;
        amba_ahb_lite_observed_item expected_item;
        amba_ahb_lite_observed_item actual_item;
        amba_ahb_lite_item intent;
        amba_ahb_lite_agent_config invalid_cfg;
        if (cfg.scenario == TB_CONFIG) begin
            report_policy.expected["AHB_CFG:Initial VIP*"] = 1;
            report_policy.expected["AHB_CFG:Only little-endian*"] = 1;
            report_policy.expected["AHB_CFG:Slave role requires*"] = 1;
            invalid_cfg = amba_ahb_lite_agent_config::type_id::create("invalid_cfg");
            invalid_cfg.data_width = 16;
            void'(invalid_cfg.validate());
            invalid_cfg.data_width = 32;
            invalid_cfg.little_endian = 1'b0;
            void'(invalid_cfg.validate());
            invalid_cfg.little_endian = 1'b1;
            invalid_cfg.role = AHB_SLAVE;
            invalid_cfg.has_hsel = 1'b0;
            void'(invalid_cfg.validate());
        end else if (cfg.scenario == TB_COPY) begin
            expected_item = observation(32'h1234);
            scoreboard.write_expected(expected_item);
            expected_item.addr = 32'hdead;
            expected_item.rdata = '0;
            actual_item = observation(32'h1234);
            scoreboard.write_actual(actual_item);
            stream.write_stream_accepted(actual_item);
            actual_item.addr = '0;
            actual_item = observation(32'h1234);
            stream.write_stream_completed(actual_item);
        end else begin
            report_policy.expected["AHB_PROTOCOL:Unaligned accepted*"] = 1;
            report_policy.expected["AHB_PROTOCOL:SEQ observed*"] = 1;
            report_policy.expected["AHB_PROTOCOL:Incorrect burst address*"] = 1;
            report_policy.expected["AHB_PROTOCOL:Address/control attributes*"] = 1;
            report_policy.expected["AHB_PROTOCOL:Completing ERROR lacked*"] = 1;
            report_policy.expected["AHB_PROTOCOL:ERROR wait must*"] = 1;
            report_policy.expected["AHB_PROTOCOL:Address/control changed*"] = 1;
            report_policy.expected["AHB_PROTOCOL:Write data changed*"] = 1;
            report_policy.expected["AHB_PROTOCOL:Fixed-length burst ended*"] = 1;
            report_policy.expected["AHB_SCOREBOARD:Actual/expected mismatch*"] = 1;
            report_policy.expected["AHB_SCOREBOARD:Unpaired streams*"] = 1;
            report_policy.expected["AHB_PREDICTOR:Unmatched master intents*"] = 1;
            report_policy.expected["AHB_STREAM:Completion/abort has no*"] = 1;
            report_policy.expected["AHB_STREAM:Accepted transfers are not*"] = 1;
            sample = cycle(32'h101);
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle();
            sample.trans = AHB_SEQ;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle();
            sample.burst = AHB_INCR;
            protocol_checker.write_checker_cycle(sample);
            sample = cycle(32'h108);
            sample.trans = AHB_SEQ;
            sample.burst = AHB_INCR;
            sample.prot = 4'b1000;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle();
            sample.pending_data = 1'b1;
            sample.trans = AHB_IDLE;
            sample.resp = AHB_ERROR;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle();
            sample.pending_data = 1'b1;
            sample.ready = 1'b0;
            sample.resp = AHB_ERROR;
            protocol_checker.write_checker_cycle(sample);
            sample = cycle();
            sample.pending_data = 1'b1;
            sample.trans = AHB_IDLE;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle();
            sample.ready = 1'b0;
            sample.pending_data = 1'b1;
            sample.pending_write = 1'b1;
            protocol_checker.write_checker_cycle(sample);
            sample = cycle(32'h104);
            sample.ready = 1'b0;
            sample.pending_data = 1'b1;
            sample.pending_write = 1'b1;
            sample.wdata = 32'hbad;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle();
            sample.burst = AHB_INCR4;
            protocol_checker.write_checker_cycle(sample);
            expected_item = observation(32'h1234);
            actual_item = observation(32'h4321);
            scoreboard.write_expected(expected_item);
            scoreboard.write_actual(actual_item);
            scoreboard.write_actual(actual_item);
            intent = amba_ahb_lite_item::type_id::create("orphan");
            predictor.write_intent(intent);
            stream.write_stream_completed(actual_item);
        end
        done.trigger();
    endtask

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        foreach (report_policy.expected[key]) begin
            if (report_policy.caught[key] != report_policy.expected[key])
                `uvm_error("AHB_SELFTEST", $sformatf(
                    "Expected diagnostic %s: wanted=%0d observed=%0d", key,
                    report_policy.expected[key], report_policy.caught[key]))
        end
    endfunction
endclass
