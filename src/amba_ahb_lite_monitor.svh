class amba_ahb_lite_monitor extends uvm_monitor;
    `uvm_component_utils(amba_ahb_lite_monitor)
    amba_ahb_lite_agent_config cfg;
    virtual amba_ahb_lite_if vif;
    uvm_analysis_port #(amba_ahb_lite_observed_item) accepted_ap;
    uvm_analysis_port #(amba_ahb_lite_observed_item) item_ap;
    uvm_analysis_port #(amba_ahb_lite_observed_item) aborted_ap;
    uvm_analysis_port #(amba_ahb_lite_cycle_item) cycle_ap;
    uvm_analysis_port #(amba_ahb_lite_reset_event) reset_ap;
    protected amba_ahb_lite_observed_item pending;
    protected int unsigned pending_wait_cycles;
    protected int unsigned reset_generation;
    protected bit in_reset;

    function new(string name = "amba_ahb_lite_monitor", uvm_component parent = null);
        super.new(name, parent);
        accepted_ap = new("accepted_ap", this);
        item_ap = new("item_ap", this);
        aborted_ap = new("aborted_ap", this);
        cycle_ap = new("cycle_ap", this);
        reset_ap = new("reset_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Monitor requires typed agent configuration")
        vif = cfg.vif;
        if (vif == null)
            `uvm_fatal("AHB_VIF", "Monitor received a null virtual interface")
    endfunction

    function logic [31:0] payload(logic [31:0] data, logic [31:0] addr,
                                 ahb_hsize_e size);
        int unsigned bytes;
        logic [31:0] mask;
        if (!ahb_size_supported(size, cfg.data_width) || $isunknown(addr))
            return 'x;
        bytes = ahb_size_bytes(size);
        mask = (bytes == 4) ? 32'hffff_ffff : ((32'h1 << (bytes * 8)) - 1);
        return (data >> (int'(addr[1:0]) * 8)) & mask;
    endfunction

    function void abort_pending(bit reset_abort);
        if (pending != null) begin
            pending.reset_abort = reset_abort;
            pending.timed_out = !reset_abort;
            pending.wait_cycles = pending_wait_cycles;
            aborted_ap.write(pending);
            pending = null;
        end
        pending_wait_cycles = 0;
    endfunction

    function void notify_reset();
        amba_ahb_lite_reset_event reset_item;
        if (in_reset)
            return;
        in_reset = 1'b1;
        reset_item = amba_ahb_lite_reset_event::type_id::create("reset_item");
        reset_generation++;
        reset_item.reset_generation = reset_generation;
        reset_item.pending_transfer_aborted = (pending != null);
        abort_pending(1'b1);
        reset_ap.write(reset_item);
    endfunction

    task observe_reset();
        forever begin
            wait (vif.HRESETn === 1'b0);
            notify_reset();
            @(posedge vif.HRESETn);
            in_reset = 1'b0;
        end
    endtask

    task observe_cycles();
        amba_ahb_lite_cycle_item sample;
        amba_ahb_lite_observed_item accepted;
        forever begin
            @(vif.monitor_cb);
            sample = amba_ahb_lite_cycle_item::type_id::create("sample");
            sample.reset_n = vif.monitor_cb.HRESETn;
            sample.addr = vif.monitor_cb.HADDR;
            sample.write = vif.monitor_cb.HWRITE;
            sample.trans = ahb_htrans_e'(vif.monitor_cb.HTRANS);
            sample.size = ahb_hsize_e'(vif.monitor_cb.HSIZE);
            sample.burst = ahb_hburst_e'(vif.monitor_cb.HBURST);
            sample.prot = vif.monitor_cb.HPROT;
            sample.mastlock = vif.monitor_cb.HMASTLOCK;
            sample.selected = (cfg.role == AHB_MASTER) || vif.monitor_cb.HSEL;
            sample.wdata = vif.monitor_cb.HWDATA;
            sample.rdata = vif.monitor_cb.HRDATA;
            sample.ready = vif.monitor_cb.HREADY;
            sample.readyout = vif.monitor_cb.HREADYOUT;
            sample.resp = ahb_hresp_e'(vif.monitor_cb.HRESP);
            sample.pending_data = (pending != null);
            sample.pending_write = pending == null ? 1'b0 : pending.write;
            sample.reset_generation = reset_generation;
            cycle_ap.write(sample);
            if (!sample.reset_n) begin
                notify_reset();
                continue;
            end
            if (pending != null) begin
                if (!sample.ready) begin
                    pending_wait_cycles++;
                    if (sample.resp == AHB_ERROR)
                        pending.error_wait_seen = 1'b1;
                    if ((cfg.max_wait_cycles != 0) &&
                            (pending_wait_cycles >= cfg.max_wait_cycles))
                        abort_pending(1'b0);
                end else begin
                    pending.wdata = payload(sample.wdata, pending.addr, pending.size);
                    pending.rdata = payload(sample.rdata, pending.addr, pending.size);
                    pending.resp = sample.resp;
                    pending.error_complete_seen = (sample.resp == AHB_ERROR);
                    pending.wait_cycles = pending_wait_cycles;
                    pending.completed = 1'b1;
                    pending.data_completed = 1'b1;
                    pending.completion_time = $time;
                    item_ap.write(pending);
                    pending = null;
                end
            end
            // Every qualified address is new, even if all fields equal the last.
            if (sample.selected && sample.ready &&
                    (sample.trans inside {AHB_NONSEQ, AHB_SEQ})) begin
                pending = amba_ahb_lite_observed_item::type_id::create("pending");
                pending.addr = sample.addr;
                pending.write = sample.write;
                pending.trans = sample.trans;
                pending.size = sample.size;
                pending.burst = sample.burst;
                pending.prot = sample.prot;
                pending.mastlock = sample.mastlock;
                pending.reset_generation = reset_generation;
                pending.address_accepted = 1'b1;
                pending.address_time = $time;
                pending_wait_cycles = 0;
                accepted = amba_ahb_lite_observed_item::type_id::create("accepted");
                accepted.copy(pending);
                accepted_ap.write(accepted);
            end
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            observe_reset();
            observe_cycles();
        join
    endtask

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (pending != null)
            `uvm_error("AHB_MONITOR", "Accepted transfer remains incomplete at end of test")
    endfunction
endclass
