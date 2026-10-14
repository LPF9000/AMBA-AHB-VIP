// Behavioral endpoint for local VIP testing, not a production DUT or predictor.
// Its byte-addressed memory and cycle scheduler are independent of VIP helpers.
class amba_ahb_lite_tb_endpoint extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_tb_endpoint)
    amba_ahb_lite_tb_cfg cfg;
    protected logic [ahb_byte_bits-1:0] memory [ahb_addr_t];
    protected bit pending;
    protected ahb_addr_t address;
    protected bit write_access;
    protected int unsigned byte_count;
    protected int unsigned delay_left;
    protected int unsigned error_phase;
    protected bit failed;
    protected int unsigned late_responses;
    protected int unsigned cleared_reads;

    function new(string name = "amba_ahb_lite_tb_endpoint", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (cfg == null || cfg.vif == null || cfg.ctrl == null)
            `uvm_fatal("AHB_CFG", "Endpoint requires typed configuration and interfaces")
    endfunction

    task observe_reset();
        forever begin
            wait (cfg.vif.HRESETn === 1'b0);
            pending = 1'b0;
            if (cfg.clear_memory)
                memory.delete();
            cfg.vif.slave_reset_ready();
            @(posedge cfg.vif.HRESETn);
        end
    endtask

    task serve();
        ahb_data_t read_bus;
        forever begin
            @(cfg.vif.monitor_cb);
            if (!cfg.vif.HRESETn || !cfg.vif.monitor_cb.HRESETn)
                continue;
            if (pending && cfg.vif.monitor_cb.HREADY) begin
                if (!write_access && cfg.scenario == TB_RESPONSE_EDGE)
                    cleared_reads++;
                if (write_access && !failed) begin
                    for (int unsigned i = 0; i < byte_count; i++)
                        memory[address + i] = cfg.vif.monitor_cb.HWDATA[
                            (((address % ahb_data_bytes) + i) * ahb_byte_bits) +: ahb_byte_bits];
                end
                pending = 1'b0;
            end
            if (cfg.vif.monitor_cb.HREADY && cfg.vif.monitor_cb.HSEL &&
                    cfg.vif.monitor_cb.HTRANS[1]) begin
                pending = 1'b1;
                address = cfg.vif.monitor_cb.HADDR;
                write_access = cfg.vif.monitor_cb.HWRITE;
                byte_count = 1 << cfg.vif.monitor_cb.HSIZE;
                delay_left = cfg.waits;
                error_phase = 0;
                failed = cfg.inject_error && write_access && address == cfg.error_addr;
            end
            // Compute the next cycle from the just-sampled accepted phase.
            read_bus = '0;
            if (pending && !write_access) begin
                for (int unsigned i = 0; i < byte_count; i++) begin
                    if (memory.exists(address + i))
                        read_bus[(((address % ahb_data_bytes) + i) * ahb_byte_bits) +: ahb_byte_bits] = memory[address + i];
                end
            end
            if (!cfg.vif.HRESETn || !pending) begin
                cfg.vif.slave_drive_cb.HREADYOUT <= 1'b1;
                cfg.vif.slave_drive_cb.HRESP <= 1'b0;
                cfg.vif.slave_drive_cb.HRDATA <= '0;
            end else if (delay_left != 0) begin
                delay_left--;
                cfg.vif.slave_drive_cb.HREADYOUT <= 1'b0;
                cfg.vif.slave_drive_cb.HRESP <= 1'b0;
            end else if (failed && error_phase == 0) begin
                error_phase = 1;
                cfg.vif.slave_drive_cb.HREADYOUT <= 1'b0;
                cfg.vif.slave_drive_cb.HRESP <= 1'b1;
            end else begin
                if (!write_access && cfg.scenario == TB_RESPONSE_LATE) begin
                    int unsigned response_reset_generation;
                    response_reset_generation = cfg.vif.reset_generation;
                    cfg.vif.slave_drive_cb.HREADYOUT <= 1'b0;
                    cfg.vif.slave_drive_cb.HRESP <= AHB_OKAY;
                    cfg.vif.slave_drive_cb.HRDATA <= '0;
                    // Deliberate slave propagation: ready/data settle after
                    // the falling edge and before the next rising edge. Raw
                    // pins model this delay; the transport adds no settle wait.
                    #(3 * tb_clock_period / 4);
                    if (cfg.vif.HRESETn &&
                            cfg.vif.reset_generation == response_reset_generation) begin
                        cfg.vif.HREADYOUT <= 1'b1;
                        cfg.vif.HRESP <= AHB_OKAY;
                        cfg.vif.HRDATA <= read_bus;
                        late_responses++;
                    end
                end else begin
                    cfg.vif.slave_drive_cb.HREADYOUT <= 1'b1;
                    cfg.vif.slave_drive_cb.HRESP <= failed;
                    cfg.vif.slave_drive_cb.HRDATA <= read_bus;
                end
            end
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            observe_reset();
            serve();
        join
    endtask

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (cfg.scenario == TB_RESPONSE_LATE && late_responses != 1)
            `uvm_error("AHB_TIMING", "Late response fixture did not execute exactly once")
        if (cfg.scenario == TB_RESPONSE_EDGE && cleared_reads != 1)
            `uvm_error("AHB_TIMING", "Same-edge read response replacement did not execute exactly once")
    endfunction
endclass
