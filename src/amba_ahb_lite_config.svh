virtual class amba_ahb_lite_responder_model extends uvm_object;
    function new(string name = "amba_ahb_lite_responder_model");
        super.new(name);
    endfunction

    pure virtual function void get_response(
        input amba_ahb_lite_item request,
        output bit [31:0] rdata,
        output ahb_hresp_e resp
    );

    // Endpoint state changes are deliberately separate from response lookup.
    // The slave BFM calls commit only after the completing global HREADY cycle.
    virtual function void commit(input amba_ahb_lite_item request,
                                                                input ahb_hresp_e resp);
    endfunction
endclass

virtual class amba_ahb_lite_response_policy extends uvm_object;
    function new(string name = "amba_ahb_lite_response_policy");
        super.new(name);
    endfunction

    pure virtual function ahb_hresp_e predict_response(input amba_ahb_lite_item request);
endclass

class amba_ahb_lite_default_response_policy extends amba_ahb_lite_response_policy;
    `uvm_object_utils(amba_ahb_lite_default_response_policy)

    function new(string name = "amba_ahb_lite_default_response_policy");
        super.new(name);
    endfunction

    virtual function ahb_hresp_e predict_response(input amba_ahb_lite_item request);
        int unsigned nbytes;
        if ($isunknown({request.addr, request.write, request.trans,
                                        request.size, request.burst, request.prot, request.wdata}))
            return AHB_ERROR;
        nbytes = ahb_size_bytes(request.size);
        if (!ahb_size_supported(request.size, 32) ||
                ((request.addr & (nbytes - 1)) != 0))
            return AHB_ERROR;
        return AHB_OKAY;
    endfunction
endclass

class amba_ahb_lite_memory_model extends amba_ahb_lite_responder_model;
    `uvm_object_utils(amba_ahb_lite_memory_model)
    protected bit [7:0] mem [longint unsigned];

    function new(string name = "amba_ahb_lite_memory_model");
        super.new(name);
    endfunction

    virtual function void get_response(
        input amba_ahb_lite_item request,
        output bit [31:0] rdata,
        output ahb_hresp_e resp
    );
        int unsigned nbytes;
        rdata = '0;
        resp = AHB_OKAY;
        if ($isunknown({request.addr, request.write, request.trans,
                                        request.size, request.burst, request.prot, request.wdata})) begin
            resp = AHB_ERROR;
            return;
        end
        nbytes = ahb_size_bytes(request.size);
        if (!ahb_size_supported(request.size, 32) ||
                ((request.addr & (nbytes - 1)) != 0)) begin
            resp = AHB_ERROR;
            return;
        end
        if (request.write) begin
            // Writes are committed by commit() after a completed OKAY response.
        end else begin
            for (int unsigned i = 0; i < nbytes; i++)
                rdata[i*8 +: 8] = mem.exists(longint'(request.addr) + longint'(i)) ?
                    mem[longint'(request.addr) + longint'(i)] : '0;
        end
    endfunction

    virtual function void commit(input amba_ahb_lite_item request,
                                                              input ahb_hresp_e resp);
        int unsigned nbytes;
        if (!request.write || (resp != AHB_OKAY) ||
                $isunknown({request.addr, request.size, request.wdata}))
            return;
        nbytes = ahb_size_bytes(request.size);
        if (!ahb_size_supported(request.size, 32) ||
                ((request.addr & (nbytes - 1)) != 0))
            return;
        for (int unsigned i = 0; i < nbytes; i++)
            mem[longint'(request.addr) + longint'(i)] = request.wdata[i*8 +: 8];
    endfunction
endclass

class amba_ahb_lite_agent_config extends uvm_object;
    `uvm_object_utils(amba_ahb_lite_agent_config)

    virtual amba_ahb_lite_if vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    ahb_vip_role_e role = AHB_MASTER;
    bit checks_enable = 1'b1;
    bit coverage_enable = 1'b0;
    bit drive_idle_on_reset = 1'b1;
    bit ready_on_reset = 1'b1;
    int unsigned addr_width = 32;
    int unsigned data_width = 32;
    bit has_hsel = 1'b1;
    bit has_hmastlock = 1'b1;
    bit little_endian = 1'b1;
    bit allow_busy = 1'b1;
    bit allow_bursts = 1'b1;
    bit flush_on_reset = 1'b1;
    bit predictor_enable = 1'b1;
    bit scoreboard_enable = 1'b1;
    int unsigned default_wait_cycles = 0;
    uvm_severity protocol_severity = UVM_ERROR;
    amba_ahb_lite_responder_model responder_model;
    amba_ahb_lite_response_policy response_policy;
    // Zero means no artificial upper bound. A nonzero value prevents a hung
    // slave from making a test unbounded and marks the request timed_out.
    int unsigned max_wait_cycles = 0;

    function new(string name = "amba_ahb_lite_agent_config");
        super.new(name);
        response_policy = amba_ahb_lite_default_response_policy::type_id::create("response_policy");
    endfunction

    function bit validate();
        if (addr_width != 32 || data_width != 32) begin
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
