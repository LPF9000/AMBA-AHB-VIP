class amba_ahb_default_response_policy extends amba_ahb_response_policy;
    `uvm_object_utils(amba_ahb_default_response_policy)

    function new(string name = "amba_ahb_default_response_policy");
        super.new(name);
    endfunction

    virtual function ahb_hresp_e predict_response(input amba_ahb_item request);
        int unsigned nbytes;
        if ($isunknown({request.addr, request.write, request.trans,
            request.size, request.burst, request.prot, request.wdata}))
            return AHB_ERROR;
        nbytes = ahb_size_bytes(request.size);
        if (!ahb_size_supported(request.size, ahb_data_width) ||
                ((request.addr & (nbytes - 1)) != 0))
            return AHB_ERROR;
        return AHB_OKAY;
    endfunction
endclass
