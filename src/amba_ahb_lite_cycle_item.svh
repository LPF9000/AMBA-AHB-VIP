// A raw sampled cycle preserves IDLE/BUSY and response timing for checking.
class amba_ahb_lite_cycle_item extends uvm_sequence_item;
    `uvm_object_utils(amba_ahb_lite_cycle_item)
    logic reset_n;
    logic [31:0] addr;
    logic write;
    ahb_htrans_e trans;
    ahb_hsize_e size;
    ahb_hburst_e burst;
    logic [3:0] prot;
    logic mastlock;
    logic selected;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic ready;
    logic readyout;
    ahb_hresp_e resp;
    bit pending_data;
    bit pending_write;
    int unsigned reset_generation;

    function new(string name = "amba_ahb_lite_cycle_item");
        super.new(name);
    endfunction
    function void do_copy(uvm_object rhs);
        amba_ahb_lite_cycle_item item;
        super.do_copy(rhs);
        if (!$cast(item, rhs))
            `uvm_fatal("AHB_COPY", "Raw cycle copied from an incompatible object")
        reset_n = item.reset_n;
        addr = item.addr;
        write = item.write;
        trans = item.trans;
        size = item.size;
        burst = item.burst;
        prot = item.prot;
        mastlock = item.mastlock;
        selected = item.selected;
        wdata = item.wdata;
        rdata = item.rdata;
        ready = item.ready;
        readyout = item.readyout;
        resp = item.resp;
        pending_data = item.pending_data;
        pending_write = item.pending_write;
        reset_generation = item.reset_generation;
    endfunction
endclass
