class amba_ahb_lite_item extends uvm_sequence_item;
    rand logic [31:0]       addr;
    rand logic              write;
    rand ahb_htrans_e     trans;
    rand ahb_hsize_e      size;
    rand ahb_hburst_e     burst;
    rand logic [3:0]        prot;
    rand logic              mastlock;
    rand logic [31:0]       wdata;

    // Response fields are filled by the master driver or monitor.  Slave
    // sequences use wait_cycles as a requested response delay and provide
    // rdata/resp as the pin-level response.
    logic [31:0]           rdata;
    ahb_hresp_e            resp;
    int unsigned           wait_cycles;
    bit                    address_accepted;
    bit                    completed;
    bit                    reset_abort;
    bit                    timed_out;
    bit                    protocol_reject;
    bit                    error_wait_seen;
    bit                    error_complete_seen;
    int unsigned           burst_index;
    int unsigned           burst_length;
    bit                    alignment_error;

    // Data fields contain packed payload bytes, not shifted physical bus lanes.
    constraint legal_transfer_c {
        trans inside {AHB_NONSEQ, AHB_SEQ};
        size inside {AHB_BYTE, AHB_HWORD, AHB_WORD};
        burst == AHB_SINGLE;
        trans == AHB_NONSEQ;
        (addr % (1 << int'(size))) == 0;
    }

    `uvm_object_utils(amba_ahb_lite_item)

    function new(string name = "amba_ahb_lite_item");
        super.new(name);
        trans = AHB_NONSEQ;
        size  = AHB_WORD;
        burst = AHB_SINGLE;
        prot  = 4'b0011;
        resp  = AHB_OKAY;
    endfunction

    function void do_copy(uvm_object rhs);
        amba_ahb_lite_item rhs_item;
        if (!$cast(rhs_item, rhs))
            `uvm_fatal("AHB_COPY", "Attempted to copy a non-AHB item")
        super.do_copy(rhs);
        addr = rhs_item.addr;
        write = rhs_item.write;
        trans = rhs_item.trans;
        size = rhs_item.size;
        burst = rhs_item.burst;
        prot = rhs_item.prot;
        mastlock = rhs_item.mastlock;
        wdata = rhs_item.wdata;
        rdata = rhs_item.rdata;
        resp = rhs_item.resp;
        wait_cycles = rhs_item.wait_cycles;
        completed = rhs_item.completed;
        address_accepted = rhs_item.address_accepted;
        reset_abort = rhs_item.reset_abort;
        timed_out = rhs_item.timed_out;
        protocol_reject = rhs_item.protocol_reject;
        error_wait_seen = rhs_item.error_wait_seen;
        error_complete_seen = rhs_item.error_complete_seen;
        burst_index = rhs_item.burst_index;
        burst_length = rhs_item.burst_length;
        alignment_error = rhs_item.alignment_error;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        amba_ahb_lite_item item;
        if (!$cast(item, rhs))
            return 1'b0;
        return (addr === item.addr) &&
            (write === item.write) &&
            (trans === item.trans) &&
            (size === item.size) &&
            (burst === item.burst) &&
            (prot === item.prot) &&
            (mastlock === item.mastlock) &&
            (wdata === item.wdata) &&
            (rdata === item.rdata) &&
            (resp === item.resp) &&
            (wait_cycles === item.wait_cycles) &&
            (completed === item.completed) &&
            (address_accepted === item.address_accepted) &&
            (reset_abort === item.reset_abort) &&
            (timed_out === item.timed_out) &&
            (protocol_reject === item.protocol_reject) &&
            (error_wait_seen === item.error_wait_seen) &&
            (error_complete_seen === item.error_complete_seen) &&
            (burst_index === item.burst_index) &&
            (burst_length === item.burst_length) &&
            (alignment_error === item.alignment_error);
    endfunction

    function string convert2string();
        return $sformatf("addr=0x%08x %s trans=%s size=%s burst=%s wdata=0x%08x rdata=0x%08x resp=%s waits=%0d done=%0b abort=%0b timeout=%0b",
            addr, write ? "WRITE" : "READ", trans.name(), size.name(), burst.name(),
            wdata, rdata, resp.name(), wait_cycles, completed, reset_abort, timed_out);
    endfunction
endclass
