class amba_ahb_single_seq extends amba_ahb_base_seq;
    `uvm_object_utils(amba_ahb_single_seq)
    rand ahb_addr_t addr;
    rand bit write;
    rand ahb_hsize_e size;
    rand ahb_data_t wdata;

    constraint legal_c {
        size inside {AHB_BYTE, AHB_HWORD, AHB_WORD};
        (addr % (1 << int'(size))) == 0;
    }

    function new(string name = "amba_ahb_single_seq");
        super.new(name);
    endfunction

    task body();
        amba_ahb_item req = make_transfer("req", addr, write, size, wdata);
        start_item(req);
        finish_item(req);
    endtask
endclass
