class amba_ahb_lite_tb_error_policy extends amba_ahb_response_policy;
    `uvm_object_utils(amba_ahb_lite_tb_error_policy)
    ahb_addr_t error_addr = tb_base_addr;

    function new(string name = "amba_ahb_lite_tb_error_policy");
        super.new(name);
    endfunction

    function ahb_hresp_e predict_response(amba_ahb_item request);
        return request.addr == error_addr && request.write ? AHB_ERROR : AHB_OKAY;
    endfunction
endclass
