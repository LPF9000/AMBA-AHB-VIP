// Behavioral endpoint for local VIP testing, not a production DUT or predictor.
// Its byte-addressed memory and cycle scheduler are independent of VIP helpers.
class amba_ahb_lite_tb_endpoint extends uvm_component;
    `uvm_component_utils(amba_ahb_lite_tb_endpoint)
    amba_ahb_lite_tb_cfg cfg;
    protected logic [7:0] memory [logic [31:0]];
    protected bit pending;
    protected logic [31:0] address;
    protected bit write_access;
    protected int unsigned byte_count;
    protected int unsigned delay_left;
    protected int unsigned error_phase;
    protected bit failed;

    function new(string name = "amba_ahb_lite_tb_endpoint", uvm_component parent = null);
        super.new(name, parent);
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
        logic [31:0] read_bus;
        forever begin
            @(cfg.vif.monitor_cb);
            if (!cfg.vif.HRESETn || !cfg.vif.monitor_cb.HRESETn)
                continue;
            if (pending && cfg.vif.monitor_cb.HREADY) begin
                if (write_access && !failed) begin
                    for (int unsigned i = 0; i < byte_count; i++)
                        memory[address + i] = cfg.vif.monitor_cb.HWDATA[
                            ((int'(address[1:0]) + i) * 8) +: 8];
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
            @(cfg.vif.slave_drive_cb);
            read_bus = '0;
            if (pending && !write_access) begin
                for (int unsigned i = 0; i < byte_count; i++) begin
                    if (memory.exists(address + i))
                        read_bus[((int'(address[1:0]) + i) * 8) +: 8] = memory[address + i];
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
                cfg.vif.slave_drive_cb.HREADYOUT <= 1'b1;
                cfg.vif.slave_drive_cb.HRESP <= failed;
                cfg.vif.slave_drive_cb.HRDATA <= read_bus;
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
