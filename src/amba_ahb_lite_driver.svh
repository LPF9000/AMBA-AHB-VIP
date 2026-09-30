class amba_ahb_lite_master_driver extends uvm_driver #(amba_ahb_lite_item);
    `uvm_component_utils(amba_ahb_lite_master_driver)

    amba_ahb_lite_agent_config cfg;
    virtual amba_ahb_lite_if vif;
    uvm_analysis_port #(amba_ahb_lite_item) request_ap;
    bit burst_open;
    uvm_analysis_port #(amba_ahb_lite_item) result_ap;

    function new(string name = "amba_ahb_lite_master_driver", uvm_component parent = null);
        super.new(name, parent);
        request_ap = new("request_ap", this);
        result_ap = new("result_ap", this);
    endfunction

    task automatic finish_with_response(amba_ahb_lite_item req);
        amba_ahb_lite_item response;
        response = amba_ahb_lite_item::type_id::create("response");
        response.copy(req);
        response.set_id_info(req);
        result_ap.write(response);
        seq_item_port.item_done();
    endtask

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Master driver requires amba_ahb_lite_agent_config")
        vif = cfg.vif;
        if (vif == null)
            `uvm_fatal("AHB_VIF", "Master driver received a null virtual interface")
        if (!cfg.validate())
            `uvm_fatal("AHB_CFG", "Invalid AMBA AHB-Lite master configuration")
    endfunction

    task serve();
        amba_ahb_lite_item req;
        logic [1:0] next_trans;
        int unsigned request_reset_generation;
        vif.master_reset_idle();
        burst_open = 1'b0;
        forever begin
            // Reset synchronization belongs to the protocol driver. Tests
            // may start sequences at time zero without peeking at pins.
            while (!vif.monitor_cb.HRESETn)
                @(vif.monitor_cb);
            seq_item_port.get_next_item(req);
            wait (vif.HRESETn === 1'b1);
            request_reset_generation = vif.reset_generation;
            if ($isunknown({req.addr, req.write, req.trans, req.size, req.burst,
                                            req.prot, req.mastlock, req.wdata})) begin
                `uvm_error("AHB_ITEM", "Unknown AHB request field; request rejected")
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            if (!ahb_size_supported(req.size, cfg.data_width) ||
                    ((req.addr & (ahb_size_bytes(req.size) - 1)) != 0)) begin
                `uvm_error("AHB_ITEM", {"Unsupported or unaligned transfer: ", req.convert2string()})
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            if ((req.trans == AHB_BUSY) && !cfg.allow_busy) begin
                `uvm_error("AHB_ITEM", "BUSY item rejected by configuration")
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            if ((req.trans == AHB_BUSY) && !burst_open) begin
                `uvm_error("AHB_ITEM", "BUSY is legal only inside an open burst")
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            if ((req.burst != AHB_SINGLE) && !cfg.allow_bursts) begin
                `uvm_error("AHB_ITEM", "Burst item rejected by configuration")
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            if (req.mastlock && !cfg.has_hmastlock) begin
                `uvm_error("AHB_ITEM", "HMASTLOCK was requested but optional pin is disabled")
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            if ((req.trans == AHB_SEQ) && !burst_open) begin
                `uvm_error("AHB_ITEM", "SEQ cannot start a burst; first beat must be NONSEQ")
                req.protocol_reject = 1'b1;
                finish_with_response(req);
                continue;
            end
            // Publish only accepted intent, before the driver mutates response and
            // completion fields. Prediction never depends on live pin state.
            if (req.trans != AHB_BUSY) begin
                amba_ahb_lite_item intent;
                intent = amba_ahb_lite_item::type_id::create("intent");
                intent.copy(req);
                request_ap.write(intent);
            end
            vif.master_drive(req.addr, req.write, req.trans, req.size, req.burst,
                                              req.prot, req.mastlock, req.wdata);
            if (req.trans == AHB_BUSY) begin
                do @(vif.master_sample_cb);
                while (vif.master_sample_cb.HRESETn && !vif.master_sample_cb.HREADY);
                req.completed = 1'b0;
                finish_with_response(req);
                continue;
            end
            next_trans = ((req.burst != AHB_SINGLE) &&
                ((req.burst_length == 0) || (req.burst_index + 1 < req.burst_length))) ?
                AHB_BUSY : AHB_IDLE;
            vif.master_complete(req.write, req.wdata, cfg.max_wait_cycles,
                                                    req.rdata, req.resp,
                                                    req.wait_cycles, req.completed, req.reset_abort,
                                                    req.timed_out, next_trans);
            req.address_accepted = vif.launch_accepted;
            if (vif.reset_generation != request_reset_generation) begin
                req.reset_abort = 1'b1;
                req.completed = 1'b0;
            end
            if (req.reset_abort || req.timed_out) begin
                burst_open = 1'b0;
                if (req.timed_out)
                    `uvm_error("AHB_TIMEOUT", $sformatf("HREADY timeout after %0d waits at address 0x%08x",
                        req.wait_cycles, req.addr))
            end else begin
                burst_open = (next_trans == AHB_BUSY) && (req.burst != AHB_SINGLE) &&
                                          (req.trans inside {AHB_NONSEQ, AHB_SEQ});
            end
            finish_with_response(req);
        end
    endtask
    task run_phase(uvm_phase phase);
        fork
            serve();
            forever begin
                @(negedge vif.HRESETn);
                vif.master_reset_idle();
                burst_open = 1'b0;
            end
        join
    endtask
endclass
