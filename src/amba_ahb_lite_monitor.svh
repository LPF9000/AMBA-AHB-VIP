class amba_ahb_lite_monitor extends uvm_monitor;
    `uvm_component_utils(amba_ahb_lite_monitor)

    amba_ahb_lite_agent_config cfg;
    virtual amba_ahb_lite_if vif;
    uvm_analysis_port #(amba_ahb_lite_observed_item) item_ap;
    uvm_analysis_port #(amba_ahb_lite_reset_event) reset_ap;
    protected amba_ahb_lite_observed_item pending;
    protected int unsigned pending_wait_cycles;
    protected bit pending_wdata_sampled;
    protected int unsigned reset_generation;
    protected bit in_reset;

    function new(string name = "amba_ahb_lite_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_ap = new("item_ap", this);
        reset_ap = new("reset_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Monitor requires amba_ahb_lite_agent_config")
        vif = cfg.vif;
        if (vif == null)
            `uvm_fatal("AHB_VIF", "Monitor received a null virtual interface")
    endfunction

    function bit is_transfer(logic [1:0] trans);
        return (trans == AHB_NONSEQ) || (trans == AHB_SEQ);
    endfunction

    function bit selected();
        // HSEL is meaningful when observing a slave interface.  A master-facing
        // monitor must not require the integration to drive this optional signal.
        return (cfg.role == AHB_MASTER) || vif.monitor_cb.HSEL;
    endfunction

    function void capture_address_phase();
        pending = amba_ahb_lite_observed_item::type_id::create("pending");
        pending.addr     = vif.monitor_cb.HADDR;
        pending.write    = vif.monitor_cb.HWRITE;
        pending.trans    = ahb_htrans_e'(vif.monitor_cb.HTRANS);
        pending.size     = ahb_hsize_e'(vif.monitor_cb.HSIZE);
        pending.burst    = ahb_hburst_e'(vif.monitor_cb.HBURST);
        pending.prot     = vif.monitor_cb.HPROT;
        pending.mastlock = vif.monitor_cb.HMASTLOCK;
        pending.wdata    = vif.monitor_cb.HWDATA;
        pending.reset_generation = reset_generation;
        pending.address_accepted = 1'b1;
        pending.address_time = $time;
        pending_wait_cycles = 0;
        pending_wdata_sampled = 1'b0;
    endfunction

    task run_phase(uvm_phase phase);
        bit same_held_phase;
        forever begin
            @(vif.monitor_cb);
            if (!vif.monitor_cb.HRESETn) begin
                if (!in_reset) begin
                    amba_ahb_lite_reset_event event_item;
                    event_item = amba_ahb_lite_reset_event::type_id::create("reset_event");
                    reset_generation++;
                    event_item.reset_generation = reset_generation;
                    event_item.pending_transfer_aborted = (pending != null);
                    reset_ap.write(event_item);
                    in_reset = 1'b1;
                end
                if (pending != null) begin
                    pending.reset_abort = 1'b1;
                    pending.completed   = 1'b0;
                    pending = null;
                end
                pending_wait_cycles = 0;
                pending_wdata_sampled = 1'b0;
                continue;
            end
            in_reset = 1'b0;

            if (pending == null) begin
                if (cfg.checks_enable &&
                        $isunknown({vif.monitor_cb.HTRANS, vif.monitor_cb.HSIZE,
                                                vif.monitor_cb.HBURST, vif.monitor_cb.HREADY}))
                    `uvm_error("AHB_PROTOCOL", "Unknown AHB control/ready value observed")
                if (selected() && vif.monitor_cb.HREADY &&
                        is_transfer(vif.monitor_cb.HTRANS))
                    capture_address_phase();
                continue;
            end

            if (!vif.monitor_cb.HREADY) begin
                if (vif.monitor_cb.HRESP == AHB_ERROR)
                    pending.error_wait_seen = 1'b1;
                if (pending.write && !pending_wdata_sampled) begin
                    pending.wdata = vif.monitor_cb.HWDATA;
                    pending_wdata_sampled = 1'b1;
                end
                if (cfg.checks_enable &&
                        ((vif.monitor_cb.HADDR !== pending.addr) ||
                          (vif.monitor_cb.HWRITE !== pending.write) ||
                          (vif.monitor_cb.HTRANS !== pending.trans) ||
                          (vif.monitor_cb.HSIZE !== pending.size) ||
                          (vif.monitor_cb.HBURST !== pending.burst) ||
                          (vif.monitor_cb.HPROT !== pending.prot) ||
                          (pending_wdata_sampled &&
                            (vif.monitor_cb.HWDATA !== pending.wdata))))
                    `uvm_error("AHB_PROTOCOL", "Address/control or write data changed during HREADY wait")
                pending_wait_cycles++;
                continue;
            end

            // HREADY high completes the pending data phase. The current bus values
            // can simultaneously be the next address phase, enabling back-to-back
            // transfers without losing a beat of a burst.
            pending.rdata       = vif.monitor_cb.HRDATA;
            if (pending.write)
                pending.wdata = vif.monitor_cb.HWDATA;
            pending.resp        = ahb_hresp_e'(vif.monitor_cb.HRESP);
            pending.error_complete_seen = (vif.monitor_cb.HRESP == AHB_ERROR);
            pending.wait_cycles = pending_wait_cycles;
            pending.completed   = 1'b1;
            pending.data_completed = 1'b1;
            pending.completion_time = $time;
            same_held_phase =
                (vif.monitor_cb.HADDR === pending.addr) &&
                (vif.monitor_cb.HWRITE === pending.write) &&
                (vif.monitor_cb.HTRANS === pending.trans) &&
                (vif.monitor_cb.HSIZE === pending.size) &&
                (vif.monitor_cb.HBURST === pending.burst) &&
                (vif.monitor_cb.HPROT === pending.prot) &&
                (vif.monitor_cb.HMASTLOCK === pending.mastlock) &&
                (!pending.write || (vif.monitor_cb.HWDATA === pending.wdata));
            begin
                amba_ahb_lite_observed_item snapshot;
                snapshot = amba_ahb_lite_observed_item::type_id::create("snapshot");
                snapshot.copy(pending);
                item_ap.write(snapshot);
            end
            pending = null;

            if (!same_held_phase && selected() && vif.monitor_cb.HREADY &&
                    is_transfer(vif.monitor_cb.HTRANS))
                capture_address_phase();
        end
    endtask
endclass
