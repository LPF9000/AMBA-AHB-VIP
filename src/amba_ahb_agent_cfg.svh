class amba_ahb_agent_cfg extends uvm_object;
    `uvm_object_utils(amba_ahb_agent_cfg)

    virtual amba_ahb_if #(ahb_addr_width, ahb_data_width) vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    ahb_vip_role_e role = AHB_MASTER;
    bit checks_enable = 1'b1;
    // Reset pin values are mandatory for this protocol profile.
    ahb_profile_e profile = ahb_compiled_profile;
    int unsigned addr_width = ahb_addr_width;
    int unsigned data_width = ahb_data_width;
    bit has_hsel = 1'b1;
    bit has_hmastlock = 1'b1;
    bit little_endian = 1'b1;
    bit allow_busy = 1'b1;
    bit allow_bursts = 1'b1;
    bit flush_on_reset = 1'b1;
    int unsigned default_wait_cycles = 0;
    bit automatic_response = 1'b1;
    uvm_severity protocol_severity = UVM_ERROR;
    amba_ahb_responder_model responder_model;
    amba_ahb_response_policy response_policy;
    // Zero means no artificial upper bound. A nonzero value prevents a hung
    // slave from making a test unbounded and marks the request timed_out.
    int unsigned max_wait_cycles = 0;

    function new(string name = "amba_ahb_agent_cfg");
        super.new(name);
        response_policy = amba_ahb_default_response_policy::type_id::create("response_policy");
    endfunction

    function bit validate();
        if (profile != AHB_PROFILE_AMBA3_LITE || profile != ahb_compiled_profile) begin
            `uvm_error("AHB_CFG", "Unsupported AHB profile; only ARM IHI 0033A AMBA 3 AHB-Lite is implemented")
            return 1'b0;
        end
        if (!(role inside {AHB_MASTER, AHB_SLAVE})) begin
            `uvm_error("AHB_CFG", "Invalid AHB agent role")
            return 1'b0;
        end
        if (!(is_active inside {UVM_ACTIVE, UVM_PASSIVE})) begin
            `uvm_error("AHB_CFG", "Invalid AHB active/passive mode")
            return 1'b0;
        end
        if (ahb_addr_width != ahb_lite_addr_width || ahb_data_width != ahb_lite_data_width ||
                addr_width != ahb_addr_width || data_width != ahb_data_width) begin
            `uvm_error("AHB_CFG", "Initial VIP transaction layer supports only 32-bit address/data")
            return 1'b0;
        end
        if ((data_width == 0) || ((data_width % 8) != 0)) begin
            `uvm_error("AHB_CFG", "AHB data_width must be a nonzero byte multiple")
            return 1'b0;
        end
        if ((role == AHB_SLAVE) && !has_hsel) begin
            `uvm_error("AHB_CFG", "Slave role requires HSEL unless an integration-specific select policy is added")
            return 1'b0;
        end
        if (!little_endian) begin
            `uvm_error("AHB_CFG", "Only little-endian lane mapping is implemented in the 32-bit baseline")
            return 1'b0;
        end
        return 1'b1;
    endfunction
endclass
