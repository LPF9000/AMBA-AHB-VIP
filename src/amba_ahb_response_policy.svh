virtual class amba_ahb_response_policy extends uvm_object;
    function new(string name = "amba_ahb_response_policy");
        super.new(name);
    endfunction

    pure virtual function ahb_hresp_e predict_response(input amba_ahb_item request);
endclass
