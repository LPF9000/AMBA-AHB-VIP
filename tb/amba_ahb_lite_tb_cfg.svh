class amba_ahb_lite_tb_cfg extends uvm_object;
    `uvm_object_utils(amba_ahb_lite_tb_cfg)
    virtual amba_ahb_if #(ahb_addr_width, ahb_data_width) vif;
    virtual amba_ahb_lite_tb_ctrl_if ctrl;
    ahb_tb_scenario_e scenario = TB_ACTIVE;
    bit randomize_sequences = 1'b1;
    ahb_data_t transfer_data = tb_transfer_data;
    bit use_simple_slave;
`ifdef AHB_UVM_MS
    amba_ahb_lite_ms_pkg::amba_ahb_lite_ms_proxy ms_proxy;
`endif
    bit use_batch_source;
    bit use_slave_vip;
    bit clear_memory = 1'b1;
    bit reset_on_transfer;
    bit reset_on_error;
    bit reset_before_accept;
    int unsigned reset_pulses = 1;
    int unsigned waits;
    bit inject_error;
    ahb_addr_t base_addr = tb_base_addr;
    ahb_addr_t burst_addr = tb_burst_addr;
    ahb_data_t retained_data = tb_retained_data;
    ahb_addr_t error_addr = tb_base_addr;
    int unsigned timeout_limit = tb_timeout_limit;
    int unsigned expected_completions;
    int unsigned expected_aborts;
    int unsigned expected_resets = 1;
    int unsigned expected_timeouts;
    int unsigned timeout_reports;
    int unsigned reject_reports;
    int unsigned expected_rejects;
    int unsigned expected_idle_results;
    uvm_event recovery_ready;
    uvm_event started;
    uvm_event main_ready;

    function new(string name = "amba_ahb_lite_tb_cfg");
        super.new(name);
        recovery_ready = new("recovery_ready");
        started = new("started");
        main_ready = new("main_ready");
    endfunction
endclass
