class amba_ahb_memory_model extends amba_ahb_responder_model;
    `uvm_object_utils(amba_ahb_memory_model)
    protected bit [ahb_byte_bits-1:0] mem [longint unsigned];

    function new(string name = "amba_ahb_memory_model");
        super.new(name);
    endfunction

    virtual function void reset(bit clear_memory);
        if (clear_memory)
            mem.delete();
    endfunction

    virtual function void get_response(
        input amba_ahb_item request,
        output ahb_data_t rdata,
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
        if (!ahb_size_supported(request.size, ahb_data_width) ||
                ((request.addr & (nbytes - 1)) != 0)) begin
            resp = AHB_ERROR;
            return;
        end
        if (request.write) begin
            // Writes are committed by commit() after a completed OKAY response.
        end else begin
            for (int unsigned i = 0; i < nbytes; i++)
                rdata[i* ahb_byte_bits +: ahb_byte_bits] = mem.exists($unsigned(longint'(request.addr)) + $unsigned(longint'(i))) ?
                    mem[$unsigned(longint'(request.addr)) + $unsigned(longint'(i))] : '0;
        end
    endfunction

    virtual function void commit(input amba_ahb_item request,
        input ahb_hresp_e resp);
        int unsigned nbytes;
        if (!request.write || (resp != AHB_OKAY) ||
                $isunknown({request.addr, request.size, request.wdata}))
            return;
        nbytes = ahb_size_bytes(request.size);
        if (!ahb_size_supported(request.size, ahb_data_width) ||
                ((request.addr & (nbytes - 1)) != 0))
            return;
        for (int unsigned i = 0; i < nbytes; i++)
            mem[$unsigned(longint'(request.addr)) + $unsigned(longint'(i))] = request.wdata[i* ahb_byte_bits +: ahb_byte_bits];
    endfunction
endclass
