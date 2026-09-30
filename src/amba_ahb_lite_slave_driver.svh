class amba_ahb_lite_slave_driver extends uvm_driver #(amba_ahb_lite_item);
    `uvm_component_utils(amba_ahb_lite_slave_driver)
    amba_ahb_lite_agent_config cfg;
    virtual amba_ahb_lite_if vif;
    protected amba_ahb_lite_item pending;
    protected amba_ahb_lite_item scripted;
    protected int unsigned waits_left;
    protected int unsigned observed_waits;
    protected int unsigned error_phase;
    protected logic [31:0] response_data;
    protected ahb_hresp_e response_kind;
    protected bit in_reset;

    function new(string name = "amba_ahb_lite_slave_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Slave driver requires typed configuration")
        vif = cfg.vif;
        if (vif == null || !cfg.validate())
            `uvm_fatal("AHB_CFG", "Slave driver requires a valid configuration and interface")
    endfunction

    function void finish_script(bit reset_abort, bit timed_out);
        if (scripted != null) begin
            scripted.completed = !reset_abort && !timed_out;
            scripted.reset_abort = reset_abort;
            scripted.timed_out = timed_out;
            scripted.wait_cycles = observed_waits;
            scripted.rdata = response_data;
            scripted.resp = response_kind;
            seq_item_port.item_done();
            scripted = null;
        end
    endfunction

    task observe_reset();
        forever begin
            wait (vif.HRESETn === 1'b0);
            in_reset = 1'b1;
            pending = null;
            finish_script(1'b1, 1'b0);
            if (cfg.responder_model != null)
                cfg.responder_model.reset(cfg.flush_on_reset);
            vif.slave_reset_ready();
            @(posedge vif.HRESETn);
            in_reset = 1'b0;
        end
    endtask

    task accept_address();
        bit [31:0] model_data;
        pending = amba_ahb_lite_item::type_id::create("pending");
        pending.addr = vif.monitor_cb.HADDR;
        pending.write = vif.monitor_cb.HWRITE;
        pending.trans = ahb_htrans_e'(vif.monitor_cb.HTRANS);
        pending.size = ahb_hsize_e'(vif.monitor_cb.HSIZE);
        pending.burst = ahb_hburst_e'(vif.monitor_cb.HBURST);
        pending.prot = vif.monitor_cb.HPROT;
        pending.mastlock = vif.monitor_cb.HMASTLOCK;
        pending.address_accepted = 1'b1;
        // Lookup uses accepted address/control. Write payload is sampled only
        // on data completion and passed to commit, never from the address phase.
        scripted = null;
        seq_item_port.try_next_item(scripted);
        waits_left = scripted == null ? cfg.default_wait_cycles : scripted.wait_cycles;
        observed_waits = 0;
        error_phase = 0;
        response_data = scripted == null ? '0 : scripted.rdata;
        response_kind = scripted == null ? AHB_OKAY : scripted.resp;
        if (cfg.responder_model != null) begin
            ahb_hresp_e model_kind;
            cfg.responder_model.get_response(pending, model_data, model_kind);
            response_data = model_data;
            if (scripted == null || response_kind == AHB_OKAY)
                response_kind = model_kind;
        end
        if (cfg.response_policy != null && response_kind == AHB_OKAY)
            response_kind = cfg.response_policy.predict_response(pending);
    endtask

    task serve();
        logic [31:0] mask;
        int unsigned bytes;
        forever begin
            @(vif.monitor_cb);
            if (!vif.monitor_cb.HRESETn || in_reset || !vif.HRESETn)
                continue;
            if (pending != null) begin
                if (vif.monitor_cb.HREADY) begin
                    bytes = ahb_size_supported(pending.size, cfg.data_width) ?
                        ahb_size_bytes(pending.size) : 0;
                    mask = bytes == 4 ? 32'hffff_ffff : ((32'h1 << (bytes * 8)) - 1);
                    pending.wdata = (vif.monitor_cb.HWDATA >>
                        (int'(pending.addr[1:0]) * 8)) & mask;
                    if (cfg.responder_model != null)
                        cfg.responder_model.commit(pending, response_kind);
                    finish_script(1'b0, 1'b0);
                    pending = null;
                end else begin
                    observed_waits++;
                    if ((cfg.max_wait_cycles != 0) &&
                            (observed_waits >= cfg.max_wait_cycles)) begin
                        finish_script(1'b0, 1'b1);
                        pending = null;
                    end
                end
            end
            if (vif.monitor_cb.HREADY && vif.monitor_cb.HSEL &&
                    (vif.monitor_cb.HTRANS inside {AHB_NONSEQ, AHB_SEQ}))
                accept_address();
            @(vif.slave_drive_cb);
            if (in_reset || !vif.HRESETn || pending == null) begin
                vif.slave_drive_cb.HREADYOUT <= 1'b1;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
            end else if (!cfg.automatic_response && scripted == null) begin
                seq_item_port.try_next_item(scripted);
                if (scripted != null) begin
                    waits_left = scripted.wait_cycles;
                    response_data = scripted.rdata;
                    response_kind = scripted.resp;
                end
                vif.slave_drive_cb.HREADYOUT <= 1'b0;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
            end else if (waits_left != 0) begin
                waits_left--;
                vif.slave_drive_cb.HREADYOUT <= 1'b0;
                vif.slave_drive_cb.HRESP <= AHB_OKAY;
                vif.slave_drive_cb.HRDATA <= '0;
            end else if (response_kind == AHB_ERROR && error_phase == 0) begin
                error_phase = 1;
                vif.slave_drive_cb.HREADYOUT <= 1'b0;
                vif.slave_drive_cb.HRESP <= AHB_ERROR;
                vif.slave_drive_cb.HRDATA <= '0;
            end else begin
                vif.slave_drive_cb.HREADYOUT <= 1'b1;
                vif.slave_drive_cb.HRESP <= response_kind;
                vif.slave_drive_cb.HRDATA <= response_data << (int'(pending.addr[1:0]) * 8);
            end
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            observe_reset();
            serve();
        join
    endtask
endclass
