import uvm_pkg::*;
import amba_ahb_lite_pkg::*;

class amba_ahb_lite_topology_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_topology_test)

    amba_ahb_lite_env env;
    amba_ahb_lite_env_config env_cfg;
    virtual amba_ahb_lite_if vif;

    function new(string name = "amba_ahb_lite_topology_test",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual amba_ahb_lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("AHB_VIF", "Topology smoke test requires a virtual interface")
        env_cfg = amba_ahb_lite_env_config::type_id::create("env_cfg");
        env_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        env_cfg.agent_cfg.vif = vif;
        env_cfg.agent_cfg.is_active = UVM_PASSIVE;
        env_cfg.enable_predictor = 1'b0;
        env_cfg.enable_scoreboard = 1'b0;
        env_cfg.enable_coverage = 1'b0;
        uvm_config_db#(amba_ahb_lite_env_config)::set(this, "env", "cfg", env_cfg);
        env = amba_ahb_lite_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask
endclass

class amba_ahb_lite_readback_observer extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_readback_observer)

    int unsigned read_count;

    function new(string name = "amba_ahb_lite_readback_observer",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        if (!item.write) begin
            read_count++;
            if (item.rdata !== 32'hcafe_beef)
                `uvm_error("AHB_READBACK", $sformatf(
                    "Expected nonzero readback 0xcafebeef, observed 0x%08x",
                    item.rdata))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        if (read_count != 1)
            `uvm_error("AHB_READBACK", $sformatf(
                "Expected one readback transfer, observed %0d", read_count))
    endfunction
endclass

class amba_ahb_lite_error_response_policy extends amba_ahb_lite_response_policy;
    `uvm_object_utils(amba_ahb_lite_error_response_policy)

    function new(string name = "amba_ahb_lite_error_response_policy");
        super.new(name);
    endfunction

    function ahb_hresp_e predict_response(input amba_ahb_lite_item request);
        return (request.write && (request.addr == 32'h0000_00c0)) ?
            AHB_ERROR : AHB_OKAY;
    endfunction
endclass

class amba_ahb_lite_error_observer extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_error_observer)

    int unsigned error_count;
    int unsigned read_count;

    function new(string name = "amba_ahb_lite_error_observer",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        if (item.resp == AHB_ERROR) begin
            error_count++;
            if (!item.error_wait_seen || !item.error_complete_seen)
                `uvm_error("AHB_ERROR", "ERROR transfer lacks both raw response markers")
        end else if (!item.write) begin
            read_count++;
            if (item.rdata !== '0)
                `uvm_error("AHB_ERROR", $sformatf(
                    "ERROR write unexpectedly changed endpoint state: readback=0x%08x",
                    item.rdata))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        if ((error_count != 1) || (read_count != 1))
            `uvm_error("AHB_ERROR", $sformatf(
                "Expected one ERROR and one zero readback, observed error=%0d read=%0d",
                error_count, read_count))
    endfunction
endclass

class amba_ahb_lite_error_smoke_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_error_smoke_test)

    amba_ahb_lite_env env;
    amba_ahb_lite_env_config env_cfg;
    amba_ahb_lite_error_observer error_observer;
    virtual amba_ahb_lite_if vif;

    function new(string name = "amba_ahb_lite_error_smoke_test",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual amba_ahb_lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("AHB_VIF", "ERROR smoke test requires a virtual interface")
        env_cfg = amba_ahb_lite_env_config::type_id::create("env_cfg");
        env_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        env_cfg.agent_cfg.vif = vif;
        env_cfg.agent_cfg.is_active = UVM_ACTIVE;
        env_cfg.agent_cfg.role = AHB_MASTER;
        env_cfg.agent_cfg.response_policy =
            amba_ahb_lite_error_response_policy::type_id::create("response_policy");
        env_cfg.enable_predictor = 1'b1;
        env_cfg.enable_scoreboard = 1'b1;
        env_cfg.enable_stream_scoreboard = 1'b1;
        uvm_config_db#(amba_ahb_lite_env_config)::set(this, "env", "cfg", env_cfg);
        env = amba_ahb_lite_env::type_id::create("env", this);
        error_observer = amba_ahb_lite_error_observer::type_id::create(
            "error_observer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.observed_export.connect(error_observer.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_single_sequence error_write;
        amba_ahb_lite_single_sequence read_after_error;
        phase.raise_objection(this);
        error_write = amba_ahb_lite_single_sequence::type_id::create("error_write");
        error_write.addr = 32'h0000_00c0;
        error_write.write = 1'b1;
        error_write.size = AHB_WORD;
        error_write.wdata = 32'hface_cafe;
        error_write.start(env.agent.sequencer);

        read_after_error = amba_ahb_lite_single_sequence::type_id::create(
            "read_after_error");
        read_after_error.addr = 32'h0000_00c0;
        read_after_error.write = 1'b0;
        read_after_error.size = AHB_WORD;
        read_after_error.wdata = '0;
        read_after_error.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

class amba_ahb_lite_reset_observer extends uvm_subscriber #(amba_ahb_lite_reset_event);
    `uvm_component_utils(amba_ahb_lite_reset_observer)

    int unsigned aborted_reset_count;

    function new(string name = "amba_ahb_lite_reset_observer",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void write(amba_ahb_lite_reset_event item);
        if (item.pending_transfer_aborted)
            aborted_reset_count++;
    endfunction

    function void check_phase(uvm_phase phase);
        if (aborted_reset_count != 1)
            `uvm_error("AHB_RESET", $sformatf(
                "Expected one pending-transfer reset abort, observed %0d",
                aborted_reset_count))
    endfunction
endclass

class amba_ahb_lite_reset_read_observer extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_reset_read_observer)

    int unsigned read_count;

    function new(string name = "amba_ahb_lite_reset_read_observer",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        if (!item.write) begin
            read_count++;
            if (item.rdata !== '0)
                `uvm_error("AHB_RESET", $sformatf(
                    "Reset-aborted write committed unexpectedly: readback=0x%08x",
                    item.rdata))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        if (read_count != 1)
            `uvm_error("AHB_RESET", $sformatf(
                "Expected one post-reset readback, observed %0d", read_count))
    endfunction
endclass

class amba_ahb_lite_reset_smoke_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_reset_smoke_test)

    amba_ahb_lite_env env;
    amba_ahb_lite_env_config env_cfg;
    amba_ahb_lite_reset_observer reset_observer;
    amba_ahb_lite_reset_read_observer read_observer;
    virtual amba_ahb_lite_if vif;

    function new(string name = "amba_ahb_lite_reset_smoke_test",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual amba_ahb_lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("AHB_VIF", "Reset smoke test requires a virtual interface")
        env_cfg = amba_ahb_lite_env_config::type_id::create("env_cfg");
        env_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        env_cfg.agent_cfg.vif = vif;
        env_cfg.agent_cfg.is_active = UVM_ACTIVE;
        env_cfg.agent_cfg.role = AHB_MASTER;
        env_cfg.agent_cfg.max_wait_cycles = 8;
        env_cfg.enable_predictor = 1'b1;
        env_cfg.enable_scoreboard = 1'b1;
        env_cfg.enable_stream_scoreboard = 1'b1;
        uvm_config_db#(amba_ahb_lite_env_config)::set(this, "env", "cfg", env_cfg);
        env = amba_ahb_lite_env::type_id::create("env", this);
        reset_observer = amba_ahb_lite_reset_observer::type_id::create(
            "reset_observer", this);
        read_observer = amba_ahb_lite_reset_read_observer::type_id::create(
            "read_observer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.reset_export.connect(reset_observer.analysis_export);
        env.observed_export.connect(read_observer.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_single_sequence reset_write;
        amba_ahb_lite_single_sequence read_after_reset;
        phase.raise_objection(this);
        reset_write = amba_ahb_lite_single_sequence::type_id::create("reset_write");
        reset_write.addr = 32'h0000_0100;
        reset_write.write = 1'b1;
        reset_write.size = AHB_WORD;
        reset_write.wdata = 32'hdead_beef;
        reset_write.start(env.agent.sequencer);

        read_after_reset = amba_ahb_lite_single_sequence::type_id::create(
            "read_after_reset");
        read_after_reset.addr = 32'h0000_0100;
        read_after_reset.write = 1'b0;
        read_after_reset.size = AHB_WORD;
        read_after_reset.wdata = '0;
        read_after_reset.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

class amba_ahb_lite_active_smoke_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_active_smoke_test)

    amba_ahb_lite_env env;
    amba_ahb_lite_env_config env_cfg;
    amba_ahb_lite_readback_observer readback_observer;
    virtual amba_ahb_lite_if vif;

    function new(string name = "amba_ahb_lite_active_smoke_test",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual amba_ahb_lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("AHB_VIF", "Active smoke test requires a virtual interface")
        env_cfg = amba_ahb_lite_env_config::type_id::create("env_cfg");
        env_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        env_cfg.agent_cfg.vif = vif;
        env_cfg.agent_cfg.is_active = UVM_ACTIVE;
        env_cfg.agent_cfg.role = AHB_MASTER;
        env_cfg.enable_predictor = 1'b1;
        env_cfg.enable_scoreboard = 1'b1;
        env_cfg.enable_stream_scoreboard = 1'b1;
        uvm_config_db#(amba_ahb_lite_env_config)::set(this, "env", "cfg", env_cfg);
        env = amba_ahb_lite_env::type_id::create("env", this);
        readback_observer = amba_ahb_lite_readback_observer::type_id::create(
            "readback_observer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.observed_export.connect(readback_observer.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_single_sequence write_seq;
        amba_ahb_lite_single_sequence read_seq;
        phase.raise_objection(this);

        write_seq = amba_ahb_lite_single_sequence::type_id::create("write_seq");
        write_seq.addr = 32'h0000_0040;
        write_seq.write = 1'b1;
        write_seq.size = AHB_WORD;
        write_seq.wdata = 32'hcafe_beef;
        write_seq.start(env.agent.sequencer);

        read_seq = amba_ahb_lite_single_sequence::type_id::create("read_seq");
        read_seq.addr = 32'h0000_0040;
        read_seq.write = 1'b0;
        read_seq.size = AHB_WORD;
        read_seq.wdata = '0;
        read_seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

class amba_ahb_lite_wait_observer extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_wait_observer)

    int unsigned observed_count;

    function new(string name = "amba_ahb_lite_wait_observer",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        observed_count++;
        if (item.wait_cycles != 2)
            `uvm_error("AHB_WAIT", $sformatf(
                "Expected exactly two global-HREADY wait cycles, observed %0d",
                item.wait_cycles))
    endfunction

    function void check_phase(uvm_phase phase);
        if (observed_count != 1)
            `uvm_error("AHB_WAIT", $sformatf(
                "Expected one waited transfer, observed %0d", observed_count))
    endfunction
endclass

class amba_ahb_lite_wait_smoke_test extends uvm_test;
    `uvm_component_utils(amba_ahb_lite_wait_smoke_test)

    amba_ahb_lite_env env;
    amba_ahb_lite_env_config env_cfg;
    amba_ahb_lite_wait_observer wait_observer;
    virtual amba_ahb_lite_if vif;

    function new(string name = "amba_ahb_lite_wait_smoke_test",
                              uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual amba_ahb_lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("AHB_VIF", "Wait smoke test requires a virtual interface")
        env_cfg = amba_ahb_lite_env_config::type_id::create("env_cfg");
        env_cfg.agent_cfg = amba_ahb_lite_agent_config::type_id::create("agent_cfg");
        env_cfg.agent_cfg.vif = vif;
        env_cfg.agent_cfg.is_active = UVM_ACTIVE;
        env_cfg.agent_cfg.role = AHB_MASTER;
        env_cfg.agent_cfg.max_wait_cycles = 8;
        env_cfg.enable_predictor = 1'b1;
        env_cfg.enable_scoreboard = 1'b1;
        env_cfg.enable_stream_scoreboard = 1'b1;
        uvm_config_db#(amba_ahb_lite_env_config)::set(this, "env", "cfg", env_cfg);
        env = amba_ahb_lite_env::type_id::create("env", this);
        wait_observer = amba_ahb_lite_wait_observer::type_id::create(
            "wait_observer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        env.observed_export.connect(wait_observer.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_single_sequence write_seq;
        phase.raise_objection(this);
        write_seq = amba_ahb_lite_single_sequence::type_id::create("write_seq");
        write_seq.addr = 32'h0000_0080;
        write_seq.write = 1'b1;
        write_seq.size = AHB_WORD;
        write_seq.wdata = 32'h1234_5678;
        write_seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

module amba_ahb_lite_uvm_smoke;
    logic hclk = 1'b0;
    logic hresetn = 1'b0;
    logic endpoint_readyout = 1'b1;
    logic wait_mode = 1'b0;
    logic error_mode = 1'b0;
    logic reset_mode = 1'b0;
    logic endpoint_resp = 1'b0;
    logic error_active = 1'b0;
    int unsigned error_wait_count = 0;
    int unsigned wait_count = 0;
    logic pending_transfer = 1'b0;
    logic pending_write = 1'b0;
    logic [31:0] pending_addr = '0;
    logic [31:0] model_mem [longint unsigned];
    amba_ahb_lite_if bus(hclk, hresetn);

    // Keep the passive checker quiet while this topology-only test is running.
    // The UVM test does not include a master or responder, so the integration
    // harness must provide deterministic idle/ready values explicitly.
    assign bus.HREADYOUT = endpoint_readyout;
    assign bus.HREADY = bus.HREADYOUT;
    assign bus.HRESP = endpoint_resp;
    assign bus.HRDATA = pending_transfer && !pending_write ?
        (model_mem.exists(pending_addr) ? model_mem[pending_addr] : '0) : '0;

    always #5 hclk = ~hclk;

    // Minimal endpoint model for the active smoke.  It is test-harness state,
    // not VIP prediction state.  Address/control are captured at acceptance;
    // write data is sampled from the data phase and committed only when that
    // phase completes.  This harness intentionally models one outstanding
    // transfer; back-to-back pipeline proof remains a follow-on test.
    always @(posedge hclk) begin
        bit completion_same_phase;
        completion_same_phase = 1'b0;
        if (!hresetn) begin
            endpoint_readyout <= 1'b1;
            endpoint_resp = 1'b0;
            error_active = 1'b0;
            error_wait_count = 0;
            wait_count = 0;
            pending_transfer = 1'b0;
            pending_write = 1'b0;
            pending_addr = '0;
        end else begin
            if (pending_transfer && bus.HREADY) begin
                completion_same_phase =
                    (bus.HWRITE === pending_write) &&
                    (bus.HADDR === pending_addr) &&
                    (bus.HTRANS inside {AHB_NONSEQ, AHB_SEQ});
                if (pending_write)
                    if (!error_active && (endpoint_resp == AHB_OKAY))
                        model_mem[longint'(pending_addr)] = bus.HWDATA;
                pending_transfer = 1'b0;
                if (error_active && (endpoint_resp == AHB_ERROR)) begin
                    error_active = 1'b0;
                    error_mode = 1'b0;
                end
            end
            if (!completion_same_phase && bus.HREADY &&
                    (bus.HTRANS inside {AHB_NONSEQ, AHB_SEQ})) begin
                pending_transfer = 1'b1;
                pending_write = bus.HWRITE;
                pending_addr = bus.HADDR;
                if (error_mode) begin
                    error_active = 1'b1;
                    error_wait_count = 1;
                end
                if (wait_mode)
                    wait_count = 2;
            end
        end
    end

    always @(negedge hclk) begin
        if (!hresetn)
            begin
                endpoint_readyout <= 1'b1;
                endpoint_resp = 1'b0;
            end
        else if (error_mode && error_active) begin
            if (error_wait_count != 0) begin
                endpoint_readyout <= 1'b0;
                endpoint_resp = AHB_ERROR;
                error_wait_count = error_wait_count - 1;
            end else begin
                endpoint_readyout <= 1'b1;
                endpoint_resp = AHB_ERROR;
            end
        end
        else if (wait_mode && (wait_count != 0)) begin
            endpoint_readyout <= 1'b0;
            endpoint_resp = AHB_OKAY;
            wait_count = wait_count - 1;
        end else begin
            endpoint_readyout <= 1'b1;
            endpoint_resp = AHB_OKAY;
        end
    end

    initial begin
        bus.HADDR = '0;
        bus.HWRITE = 1'b0;
        bus.HTRANS = 2'b00;
        bus.HSIZE = 3'b010;
        bus.HBURST = 3'b000;
        bus.HPROT = 4'b0011;
        bus.HMASTLOCK = 1'b0;
        bus.HSEL = 1'b1;
        bus.HWDATA = '0;
        begin
            string selected_test;
            if (!$value$plusargs("UVM_TESTNAME=%s", selected_test))
                selected_test = "";
            wait_mode = (selected_test == "amba_ahb_lite_wait_smoke_test");
            wait_mode = wait_mode ||
                (selected_test == "amba_ahb_lite_reset_smoke_test");
            error_mode = (selected_test == "amba_ahb_lite_error_smoke_test");
            reset_mode = (selected_test == "amba_ahb_lite_reset_smoke_test");
        end
        uvm_config_db#(virtual amba_ahb_lite_if)::set(
            null, "uvm_test_top", "vif", bus);
        // Let UVM_TESTNAME select topology or an active directed smoke using
        // standard command-line test selection at time zero.
        run_test();
    end

    initial begin
        repeat (2) @(posedge hclk);
        hresetn = 1'b1;
        if (reset_mode) begin
            repeat (4) @(posedge hclk);
            hresetn = 1'b0;
            @(posedge hclk);
            hresetn = 1'b1;
        end
    end
endmodule
