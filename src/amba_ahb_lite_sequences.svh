class amba_ahb_lite_single_sequence extends uvm_sequence #(amba_ahb_lite_item);
    `uvm_object_utils(amba_ahb_lite_single_sequence)
    rand bit [31:0] addr;
    rand bit write;
    rand ahb_hsize_e size;
    rand bit [31:0] wdata;

    constraint legal_c { size inside {AHB_BYTE, AHB_HWORD, AHB_WORD}; }

    function new(string name = "amba_ahb_lite_single_sequence");
        super.new(name);
    endfunction

    task body();
        amba_ahb_lite_item req = amba_ahb_lite_item::type_id::create("req");
        start_item(req);
        req.addr = addr;
        req.write = write;
        req.size = size;
        req.wdata = wdata;
        req.trans = AHB_NONSEQ;
        req.burst = AHB_SINGLE;
        finish_item(req);
    endtask
endclass

class amba_ahb_lite_burst_sequence extends uvm_sequence #(amba_ahb_lite_item);
    `uvm_object_utils(amba_ahb_lite_burst_sequence)
    rand bit [31:0] addr;
    rand bit write;
    rand ahb_hsize_e size;
    rand ahb_hburst_e burst;
    rand int unsigned incr_length;
    rand bit [31:0] data[];

    constraint legal_c {
        size inside {AHB_BYTE, AHB_HWORD, AHB_WORD};
        incr_length inside {[1:256]};
    }

    function new(string name = "amba_ahb_lite_burst_sequence");
        super.new(name);
    endfunction

    function automatic bit [31:0] next_address(bit [31:0] current,
                                                                                            ahb_hsize_e transfer_size,
                                                                                            ahb_hburst_e burst_kind);
        longint unsigned bytes = longint'(ahb_size_bytes(transfer_size));
        longint unsigned beats = longint'(ahb_burst_length(burst_kind));
        longint unsigned candidate = longint'(current) + bytes;
        longint unsigned base;
        longint unsigned boundary;
        if (!ahb_is_wrapping(burst_kind))
            return candidate[31:0];
        boundary = beats * bytes;
        base = (longint'(current) / boundary) * boundary;
        if (candidate >= (base + boundary))
            candidate = base;
        return candidate[31:0];
    endfunction

    task body();
        int unsigned beats = ahb_burst_length(burst);
        bit [31:0] current = addr;
        if (beats == 0)
            beats = incr_length;
        if (data.size() < beats)
            data = new[beats];
        for (int unsigned i = 0; i < beats; i++) begin
            amba_ahb_lite_item req = amba_ahb_lite_item::type_id::create($sformatf("beat_%0d", i));
            if ((current[31:10] != addr[31:10]) && !ahb_is_wrapping(burst)) begin
                `uvm_error("AHB_BURST", "Burst crosses the AHB 1-KB boundary")
                return;
            end
            start_item(req);
            req.addr = current;
            req.write = write;
            req.size = size;
            req.burst = burst;
            req.trans = (i == 0) ? AHB_NONSEQ : AHB_SEQ;
            req.wdata = data[i];
            req.burst_index = i;
            req.burst_length = beats;
            finish_item(req);
            current = next_address(current, size, burst);
        end
    endtask
endclass
