class amba_ahb_lite_tb_cfg extends uvm_object;
    `uvm_object_utils(amba_ahb_lite_tb_cfg)
    virtual amba_ahb_lite_if vif;
    virtual amba_ahb_lite_tb_ctrl_if ctrl;
    ahb_tb_scenario_e scenario = TB_ACTIVE;
    bit use_batch_source;
    bit use_slave_vip;
    bit clear_memory = 1'b1;
    bit reset_on_transfer;
    bit reset_on_error;
    bit reset_before_accept;
    int unsigned reset_pulses = 1;
    int unsigned waits;
    int unsigned global_waits;
    bit inject_error;
    logic [31:0] error_addr = 32'h100;
    int unsigned expected_completions;
    int unsigned expected_aborts;
    int unsigned expected_resets = 1;
    int unsigned expected_timeouts;
    int unsigned timeout_reports;
    int unsigned reject_reports;
    int unsigned expected_rejects;
    uvm_event recovery_ready;
    uvm_event started;

    function new(string name = "amba_ahb_lite_tb_cfg");
        super.new(name);
        recovery_ready = new("recovery_ready");
        started = new("started");
    endfunction
endclass

class amba_ahb_lite_tb_batch_item extends uvm_sequence_item;
    `uvm_object_utils(amba_ahb_lite_tb_batch_item)
    amba_ahb_lite_item transfers[$];

    function new(string name = "amba_ahb_lite_tb_batch_item");
        super.new(name);
    endfunction
endclass

class amba_ahb_lite_tb_error_policy extends amba_ahb_lite_response_policy;
    `uvm_object_utils(amba_ahb_lite_tb_error_policy)
    logic [31:0] error_addr = 32'h100;

    function new(string name = "amba_ahb_lite_tb_error_policy");
        super.new(name);
    endfunction

    function ahb_hresp_e predict_response(amba_ahb_lite_item item);
        return item.addr == error_addr && item.write ? AHB_ERROR : AHB_OKAY;
    endfunction
endclass
