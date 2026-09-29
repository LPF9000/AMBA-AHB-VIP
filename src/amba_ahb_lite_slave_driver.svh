class amba_ahb_lite_slave_driver extends uvm_driver #(amba_ahb_lite_item);
    `uvm_component_utils(amba_ahb_lite_slave_driver)

    amba_ahb_lite_agent_config cfg;
    virtual amba_ahb_lite_if vif;

    function new(string name = "amba_ahb_lite_slave_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task automatic finish_with_response(amba_ahb_lite_item request);
        amba_ahb_lite_item response;
        response = amba_ahb_lite_item::type_id::create("response");
        response.copy(request);
        response.set_id_info(request);
        seq_item_port.item_done(response);
    endtask

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Slave driver requires amba_ahb_lite_agent_config")
        vif = cfg.vif;
        if (vif == null)
            `uvm_fatal("AHB_VIF", "Slave driver received a null virtual interface")
        if (!cfg.validate())
            `uvm_fatal("AHB_CFG", "Invalid AMBA AHB-Lite slave configuration")
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_item rsp;
        amba_ahb_lite_item request;
        int unsigned delay;
        int unsigned wait_count;
        bit accept_timed_out;
        bit response_timed_out;
        bit [31:0] model_rdata;
        ahb_hresp_e model_resp;
        int unsigned requested_delay;
        if (cfg.ready_on_reset) begin
            vif.slave_drive_cb.HREADYOUT <= 1'b1;
            vif.slave_drive_cb.HRESP     <= AHB_OKAY;
            vif.slave_drive_cb.HRDATA    <= '0;
        end
        forever begin
            seq_item_port.get_next_item(rsp);
            wait_count = 0;
            accept_timed_out = 1'b0;
            // The address phase is sampled at posedge. BUSY/IDLE are not transfers.
            forever begin
                @(vif.monitor_cb);
                if (!vif.monitor_cb.HRESETn)
                    break;
                if (!vif.monitor_cb.HREADY) begin
                    wait_count++;
                    if ((cfg.max_wait_cycles != 0) &&
                            (wait_count >= cfg.max_wait_cycles)) begin
                        accept_timed_out = 1'b1;
                        break;
                    end
                end
                if (vif.monitor_cb.HREADY && vif.monitor_cb.HSEL &&
                        !(vif.monitor_cb.HTRANS inside {AHB_IDLE, AHB_BUSY}))
                    break;
            end
            if (!vif.monitor_cb.HRESETn) begin
                rsp.reset_abort = 1'b1;
                vif.slave_drive_cb.HREADYOUT <= 1'b1;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
                finish_with_response(rsp);
                continue;
            end
            if (accept_timed_out) begin
                rsp.timed_out = 1'b1;
                rsp.wait_cycles = wait_count;
                vif.slave_drive_cb.HREADYOUT <= 1'b1;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
                finish_with_response(rsp);
                continue;
            end
            request = amba_ahb_lite_item::type_id::create("request");
            request.addr     = vif.monitor_cb.HADDR;
            request.write    = vif.monitor_cb.HWRITE;
            request.trans    = ahb_htrans_e'(vif.monitor_cb.HTRANS);
            request.size     = ahb_hsize_e'(vif.monitor_cb.HSIZE);
            request.burst    = ahb_hburst_e'(vif.monitor_cb.HBURST);
            request.prot     = vif.monitor_cb.HPROT;
            request.mastlock = vif.monitor_cb.HMASTLOCK;
            request.wdata    = vif.monitor_cb.HWDATA;
            requested_delay = rsp.wait_cycles;
            // AHB write data belongs to the data phase, not the accepted
            // address phase. Hold the response until that phase is sampled so
            // a responder model cannot inspect stale address-phase data.
            if (request.write) begin
                @(vif.slave_drive_cb);
                vif.slave_drive_cb.HREADYOUT <= 1'b0;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
                @(vif.monitor_cb);
                if (!vif.monitor_cb.HRESETn) begin
                    rsp.reset_abort = 1'b1;
                    vif.slave_drive_cb.HREADYOUT <= 1'b1;
                    vif.slave_drive_cb.HRESP <= AHB_OKAY;
                    vif.slave_drive_cb.HRDATA <= '0;
                    finish_with_response(rsp);
                    continue;
                end
                request.wdata = vif.monitor_cb.HWDATA;
                rsp.wait_cycles = requested_delay + 1;
                if ((cfg.max_wait_cycles != 0) &&
                        (rsp.wait_cycles >= cfg.max_wait_cycles)) begin
                    rsp.timed_out = 1'b1;
                    vif.slave_drive_cb.HREADYOUT <= 1'b1;
                    vif.slave_drive_cb.HRESP <= AHB_OKAY;
                    vif.slave_drive_cb.HRDATA <= '0;
                    finish_with_response(rsp);
                    continue;
                end
            end
            if (cfg.responder_model != null) begin
                cfg.responder_model.get_response(request, model_rdata, model_resp);
                rsp.rdata = model_rdata;
                rsp.resp = model_resp;
            end else if ((cfg.response_policy != null) && (rsp.resp == AHB_OKAY)) begin
                // A shared policy prevents the independent predictor and scripted
                // responder from disagreeing about deterministic request failures.
                rsp.resp = cfg.response_policy.predict_response(request);
            end
            delay = requested_delay;
            if (delay == 0)
                delay = cfg.default_wait_cycles;
            repeat (delay) begin
                @(vif.slave_drive_cb);
                vif.slave_drive_cb.HREADYOUT <= 1'b0;
                vif.slave_drive_cb.HRESP     <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA    <= '0;
            end
            // AHB-Lite ERROR is a two-cycle response: an ERROR cycle with ready
            // low, followed by the completing ERROR cycle with ready high.
            if (rsp.resp == AHB_ERROR) begin
                @(vif.slave_drive_cb);
                vif.slave_drive_cb.HREADYOUT <= 1'b0;
                vif.slave_drive_cb.HRESP     <= AHB_ERROR;
                vif.slave_drive_cb.HRDATA    <= rsp.rdata;
                @(vif.monitor_cb);
                if (!vif.monitor_cb.HRESETn) begin
                    rsp.reset_abort = 1'b1;
                    vif.slave_drive_cb.HREADYOUT <= 1'b1;
                    vif.slave_drive_cb.HRESP <= AHB_OKAY;
                    vif.slave_drive_cb.HRDATA <= '0;
                    finish_with_response(rsp);
                    continue;
                end
            end
            @(vif.slave_drive_cb);
            vif.slave_drive_cb.HREADYOUT <= 1'b1;
            vif.slave_drive_cb.HRESP     <= rsp.resp;
            vif.slave_drive_cb.HRDATA    <= rsp.rdata;
            // HREADY is composed by the integration/interconnect. Do not use
            // HREADYOUT as a substitute when another subordinate may be selected.
            response_timed_out = 1'b0;
            wait_count = 0;
            forever begin
                @(vif.monitor_cb);
                if (!vif.monitor_cb.HRESETn)
                    break;
                if (!vif.monitor_cb.HREADY) begin
                    wait_count++;
                    if ((cfg.max_wait_cycles != 0) &&
                            (wait_count >= cfg.max_wait_cycles)) begin
                        response_timed_out = 1'b1;
                        break;
                    end
                end else begin
                    break;
                end
            end
            if (!vif.monitor_cb.HRESETn) begin
                rsp.reset_abort = 1'b1;
                vif.slave_drive_cb.HREADYOUT <= 1'b1;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
                finish_with_response(rsp);
                continue;
            end
            if (response_timed_out) begin
                rsp.timed_out = 1'b1;
                rsp.wait_cycles += wait_count;
                vif.slave_drive_cb.HREADYOUT <= 1'b1;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
                finish_with_response(rsp);
                continue;
            end
            rsp.completed = 1'b1;
            if (cfg.responder_model != null)
                cfg.responder_model.commit(request, rsp.resp);
            finish_with_response(rsp);
            @(vif.slave_drive_cb);
            vif.slave_drive_cb.HREADYOUT <= 1'b1;
            vif.slave_drive_cb.HRESP     <= AHB_OKAY;
            vif.slave_drive_cb.HRDATA    <= '0;
        end
    endtask
endclass
