class amba_ahb_burst_seq extends amba_ahb_base_seq;
    `uvm_object_utils(amba_ahb_burst_seq)
    rand ahb_addr_t addr;
    rand bit write;
    rand ahb_hsize_e size;
    rand ahb_hburst_e burst;
    rand int unsigned incr_length;
    rand ahb_data_t data[];
    int unsigned max_incr_length = ahb_default_incr_limit;

    constraint legal_c {
        size inside {AHB_BYTE, AHB_HWORD, AHB_WORD};
        incr_length inside {[1:max_incr_length]};
        solve burst, incr_length, size before addr, data;
        (addr % (1 << int'(size))) == 0;
        data.size() == int'((burst == AHB_INCR) ? incr_length :
            (burst inside {AHB_WRAP4, AHB_INCR4}) ? ahb_burst4_beats :
            (burst inside {AHB_WRAP8, AHB_INCR8}) ? ahb_burst8_beats :
            (burst inside {AHB_WRAP16, AHB_INCR16}) ? ahb_burst16_beats : 1);
        if (!(burst inside {AHB_WRAP4, AHB_WRAP8, AHB_WRAP16}))
            (addr % ahb_burst_boundary_bytes) + unsigned'(data.size()) * unsigned'(1 << int'(size)) <= ahb_burst_boundary_bytes;
    }

    function new(string name = "amba_ahb_burst_seq");
        super.new(name);
    endfunction

    function automatic ahb_addr_t next_address(ahb_addr_t current,
        ahb_hsize_e transfer_size,
        ahb_hburst_e burst_kind);
        longint unsigned bytes = $unsigned(longint'(ahb_size_bytes(transfer_size)));
        longint unsigned beats = $unsigned(longint'(ahb_burst_length(burst_kind)));
        longint unsigned candidate = $unsigned(longint'(current)) + bytes;
        longint unsigned base;
        longint unsigned boundary;
        if (!ahb_is_wrapping(burst_kind))
            return ahb_addr_t'(candidate);
        boundary = beats * bytes;
        base = ($unsigned(longint'(current)) / boundary) * boundary;
        if (candidate >= (base + boundary))
            candidate = base;
        return ahb_addr_t'(candidate);
    endfunction

    task body();
        int unsigned beats = ahb_burst_length(burst);
        ahb_addr_t current = addr;
        if (beats == 0)
            beats = incr_length;
        if (unsigned'(data.size()) < beats)
            data = new[beats];
        for (int unsigned i = 0; i < beats; i++) begin
            amba_ahb_item req = make_transfer($sformatf("beat_%0d", i),
                current, write, size, data[i], (i == 0) ? AHB_NONSEQ : AHB_SEQ, burst);
            if (((current / ahb_burst_boundary_bytes) != (addr / ahb_burst_boundary_bytes)) && !ahb_is_wrapping(burst)) begin
                `uvm_error("AHB_BURST", "Burst crosses the AHB 1-KB boundary")
                return;
            end
            start_item(req);
            req.burst_index = i;
            req.burst_length = beats;
            finish_item(req);
            current = next_address(current, size, burst);
        end
    endtask
endclass
