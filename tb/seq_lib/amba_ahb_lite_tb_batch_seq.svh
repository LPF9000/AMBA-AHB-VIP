class amba_ahb_lite_tb_batch_seq extends uvm_sequence #(amba_ahb_lite_tb_batch_item);
    `uvm_object_utils(amba_ahb_lite_tb_batch_seq)
    amba_ahb_lite_tb_cfg cfg;

    function new(string name = "amba_ahb_lite_tb_batch_seq");
        super.new(name);
    endfunction

    function void add_transfer(amba_ahb_lite_tb_batch_item batch, ahb_addr_t addr,
                                bit write_access, ahb_data_t data,
                                ahb_htrans_e trans = AHB_NONSEQ,
                                ahb_hburst_e burst = AHB_SINGLE);
        amba_ahb_item item;
        item = amba_ahb_item::type_id::create("transfer");
        item.addr = addr;
        item.write = write_access;
        item.wdata = data;
        item.trans = trans;
        item.burst = burst;
        item.mastlock = cfg.scenario inside {TB_BURSTS, TB_BURST_ERROR};
        item.prot = tb_burst_prot;
        batch.transfers.push_back(item);
        if (trans inside {AHB_NONSEQ, AHB_SEQ})
            cfg.expected_completions++;
    endfunction

    task body();
        amba_ahb_lite_tb_batch_item batch;
        batch = amba_ahb_lite_tb_batch_item::type_id::create("batch");
        start_item(batch);
        if (cfg.scenario inside {TB_BURSTS, TB_BURST_ERROR}) begin
            for (int unsigned kind = 1; kind < 8; kind++) begin
                ahb_hburst_e burst = ahb_hburst_e'(kind);
                int unsigned beats = ahb_burst_length(burst);
                ahb_addr_t addr = cfg.burst_addr;
                if (beats == 0)
                    beats = tb_incr_beats;
                if (ahb_is_wrapping(burst))
                    addr += beats * ahb_data_bytes - ahb_data_bytes;
                for (int unsigned beat = 0; beat < beats; beat++) begin
                    add_transfer(batch, addr, 1'b1, tb_burst_data + beat,
                        beat == 0 ? AHB_NONSEQ : AHB_SEQ, burst);
                    if (beat == 0)
                        add_transfer(batch, ahb_is_wrapping(burst) ? cfg.burst_addr : addr + ahb_data_bytes,
                            1'b1, '0, AHB_BUSY, burst);
                    if (ahb_is_wrapping(burst))
                        addr = cfg.burst_addr + ((addr + ahb_data_bytes - cfg.burst_addr) % (beats * ahb_data_bytes));
                    else
                        addr += ahb_data_bytes;
                end
                add_transfer(batch, '0, 1'b0, '0, AHB_IDLE);
                add_transfer(batch, cfg.burst_addr, 1'b0, '0);
            end
        end else begin
            // Identical accepted requests must remain separate transactions.
            add_transfer(batch, cfg.base_addr, 1'b1, cfg.transfer_data);
            add_transfer(batch, cfg.base_addr, 1'b1, cfg.transfer_data);
            add_transfer(batch, (cfg.base_addr + ahb_data_bytes), 1'b1, tb_second_data);
            add_transfer(batch, cfg.base_addr, 1'b0, '0);
            add_transfer(batch, (cfg.base_addr + ahb_data_bytes), 1'b0, '0);
            add_transfer(batch, (cfg.base_addr + ahb_data_bytes), 1'b0, '0);
        end
        finish_item(batch);
    endtask
endclass
