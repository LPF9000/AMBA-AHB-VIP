class amba_ahb_lite_tb_unit_checks extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_tb_unit_checks)
    amba_ahb_lite_tb_cfg cfg;
    uvm_event done;
    amba_ahb_agent_cfg agent_cfg;
    amba_ahb_protocol_checker protocol_checker;
    amba_ahb_scoreboard scoreboard;
    amba_ahb_predictor predictor;
    amba_ahb_stream_scoreboard stream;
    amba_ahb_lite_tb_report_policy report_policy;

    function new(string name = "amba_ahb_lite_tb_unit_checks", uvm_component parent = null);
        super.new(name, parent);
        done = new("done");
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (cfg == null)
            `uvm_fatal("AHB_CFG", "Unit checks require typed testbench configuration")
        report_policy = amba_ahb_lite_tb_report_policy::type_id::create("report_policy");
        uvm_report_cb::add(null, report_policy);
        agent_cfg = amba_ahb_agent_cfg::type_id::create("agent_cfg");
        uvm_config_db#(amba_ahb_agent_cfg)::set(this, "protocol_checker", "cfg", agent_cfg);
        uvm_config_db#(amba_ahb_agent_cfg)::set(this, "predictor", "cfg", agent_cfg);
        uvm_config_db#(amba_ahb_agent_cfg)::set(this, "scoreboard", "cfg", agent_cfg);
        protocol_checker = amba_ahb_protocol_checker::type_id::create("protocol_checker", this);
        scoreboard = amba_ahb_scoreboard::type_id::create("scoreboard", this);
        predictor = amba_ahb_predictor::type_id::create("predictor", this);
        stream = amba_ahb_stream_scoreboard::type_id::create("stream", this);
    endfunction

    function amba_ahb_cycle_item cycle(ahb_addr_t addr);
        amba_ahb_cycle_item item;
        item = amba_ahb_cycle_item::type_id::create("cycle");
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

    function amba_ahb_observed_item observation(ahb_data_t data = '0);
        amba_ahb_observed_item item;
        item = amba_ahb_observed_item::type_id::create("observation");
        item.addr = tb_base_addr;
        item.completed = 1'b1;
        item.address_accepted = 1'b1;
        item.data_completed = 1'b1;
        item.rdata = data;
        return item;
    endfunction

    function void reset_checker();
        amba_ahb_reset_event item;
        item = amba_ahb_reset_event::type_id::create("reset_item");
        protocol_checker.write_checker_reset(item);
    endfunction

    function void check_expected_report_policy();
        amba_ahb_lite_tb_cfg policy_cfg;
        amba_ahb_lite_tb_timeout_policy policy;
        policy_cfg = amba_ahb_lite_tb_cfg::type_id::create("policy_cfg");
        policy_cfg.expected_timeouts = 1;
        policy_cfg.expected_rejects = 1;
        policy = amba_ahb_lite_tb_timeout_policy::type_id::create("bounded_policy");
        policy.cfg = policy_cfg;
        report_policy.expected["AHB_TIMEOUT:probe excess timeout"] = 1;
        report_policy.expected["AHB_ITEM:probe excess rejection"] = 1;
        report_policy.expected["AHB_TIMEOUT:probe unrelated timeout"] = 1;
        report_policy.expected["AHB_ITEM:probe unrelated rejection"] = 1;
        report_policy.expected["AHB_TIMEOUT:probe after removal"] = 1;
        // Place the independent diagnostic collector after the policy under test.
        uvm_report_cb::delete(null, report_policy);
        uvm_report_cb::add(this, policy);
        uvm_report_cb::add(this, report_policy);
        uvm_report_cb::add(scoreboard, report_policy);
        scoreboard.uvm_report_error("AHB_TIMEOUT", "probe unrelated timeout");
        scoreboard.uvm_report_error("AHB_ITEM", "probe unrelated rejection");
        if (policy_cfg.timeout_reports != 0 || policy_cfg.reject_reports != 0)
            `uvm_error("AHB_UNIT", "Expected-error policy caught another component's report")
        uvm_report_error("AHB_TIMEOUT", "probe expected timeout");
        uvm_report_error("AHB_ITEM", "probe expected rejection");
        uvm_report_error("AHB_TIMEOUT", "probe excess timeout");
        uvm_report_error("AHB_ITEM", "probe excess rejection");
        if (policy_cfg.timeout_reports != 1 || policy_cfg.reject_reports != 1)
            `uvm_error("AHB_UNIT", "Expected-error policy did not enforce report limits")
        uvm_report_cb::delete(this, policy);
        uvm_report_error("AHB_TIMEOUT", "probe after removal");
        uvm_report_cb::delete(this, report_policy);
        uvm_report_cb::delete(scoreboard, report_policy);
        uvm_report_cb::add(null, report_policy);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_cycle_item sample;
        amba_ahb_observed_item expected_item;
        amba_ahb_observed_item actual_item;
        amba_ahb_item intent;
        amba_ahb_agent_cfg invalid_cfg;
        if (cfg.scenario == TB_CONFIG) begin
            check_expected_report_policy();
            report_policy.expected["AHB_CFG:Initial VIP*"] = 1;
            report_policy.expected["AHB_CFG:Only little-endian*"] = 1;
            report_policy.expected["AHB_CFG:Slave role requires*"] = 1;
            report_policy.expected["AHB_CFG:Unsupported AHB profile*"] = 1;
            report_policy.expected["AHB_CFG:Invalid AHB agent role*"] = 1;
            invalid_cfg = amba_ahb_agent_cfg::type_id::create("invalid_cfg");
            if (!invalid_cfg.validate())
                `uvm_error("AHB_UNIT", "Default compiled profile configuration was rejected")
            invalid_cfg.data_width = ahb_data_width / 2;
            if (invalid_cfg.validate())
                `uvm_error("AHB_UNIT", "Unsupported runtime width was accepted")
            invalid_cfg.data_width = ahb_data_width;
            invalid_cfg.little_endian = 1'b0;
            void'(invalid_cfg.validate());
            invalid_cfg.little_endian = 1'b1;
            invalid_cfg.role = AHB_SLAVE;
            invalid_cfg.has_hsel = 1'b0;
            void'(invalid_cfg.validate());
            invalid_cfg.has_hsel = 1'b1;
            invalid_cfg.profile = ahb_profile_e'('1);
            if (invalid_cfg.validate())
                `uvm_error("AHB_UNIT", "Unsupported profile was accepted")
            invalid_cfg.profile = ahb_compiled_profile;
            invalid_cfg.role = ahb_vip_role_e'('1);
            if (invalid_cfg.validate())
                `uvm_error("AHB_UNIT", "Invalid role was accepted")
            invalid_cfg.role = AHB_MASTER;
            // UVM defines mode as a one-bit enum: both representable values
            // are legal. Exercise both rather than casting an invalid integer
            // that silently truncates to UVM_ACTIVE.
            invalid_cfg.is_active = UVM_PASSIVE;
            if (!invalid_cfg.validate())
                `uvm_error("AHB_UNIT", "Passive mode was rejected")
            invalid_cfg.is_active = UVM_ACTIVE;
            if (!invalid_cfg.validate())
                `uvm_error("AHB_UNIT", "Active mode was rejected")
        end else if (cfg.scenario == TB_COPY) begin
            expected_item = observation(tb_copy_data);
            scoreboard.write_expected(expected_item);
            expected_item.addr = tb_mutated_addr;
            expected_item.rdata = '0;
            actual_item = observation(tb_copy_data);
            scoreboard.write_actual(actual_item);
            stream.write_stream_accepted(actual_item);
            actual_item.addr = '0;
            actual_item = observation(tb_copy_data);
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
            sample = cycle((cfg.base_addr + 1));
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle(cfg.base_addr);
            sample.trans = AHB_SEQ;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle(cfg.base_addr);
            sample.burst = AHB_INCR;
            protocol_checker.write_checker_cycle(sample);
            sample = cycle((cfg.base_addr + 2 * ahb_data_bytes));
            sample.trans = AHB_SEQ;
            sample.burst = AHB_INCR;
            sample.prot = tb_bad_prot;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle(cfg.base_addr);
            sample.pending_data = 1'b1;
            sample.trans = AHB_IDLE;
            sample.resp = AHB_ERROR;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle(cfg.base_addr);
            sample.pending_data = 1'b1;
            sample.ready = 1'b0;
            sample.resp = AHB_ERROR;
            protocol_checker.write_checker_cycle(sample);
            sample = cycle(cfg.base_addr);
            sample.pending_data = 1'b1;
            sample.trans = AHB_IDLE;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle(cfg.base_addr);
            sample.ready = 1'b0;
            sample.pending_data = 1'b1;
            sample.pending_write = 1'b1;
            protocol_checker.write_checker_cycle(sample);
            sample = cycle((cfg.base_addr + ahb_data_bytes));
            sample.ready = 1'b0;
            sample.pending_data = 1'b1;
            sample.pending_write = 1'b1;
            sample.wdata = tb_bad_data;
            protocol_checker.write_checker_cycle(sample);
            reset_checker();
            sample = cycle(cfg.base_addr);
            sample.burst = AHB_INCR4;
            protocol_checker.write_checker_cycle(sample);
            expected_item = observation(tb_copy_data);
            actual_item = observation(tb_mismatch_data);
            scoreboard.write_expected(expected_item);
            scoreboard.write_actual(actual_item);
            scoreboard.write_actual(actual_item);
            intent = amba_ahb_item::type_id::create("orphan");
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

    function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        uvm_report_cb::delete(null, report_policy);
    endfunction
endclass
