virtual class amba_ahb_responder_model extends uvm_object;
    function new(string name = "amba_ahb_responder_model");
        super.new(name);
    endfunction

    // Lookup receives address/control and packed payload when available.
    virtual function void reset(bit clear_memory);
    endfunction

    pure virtual function void get_response(
        input amba_ahb_item request,
        output ahb_data_t rdata,
        output ahb_hresp_e resp
    );

    // Endpoint state changes are deliberately separate from response lookup.
    // The slave BFM calls commit only after the completing global HREADY cycle.
    virtual function void commit(input amba_ahb_item request,
        input ahb_hresp_e resp);
    endfunction
endclass
