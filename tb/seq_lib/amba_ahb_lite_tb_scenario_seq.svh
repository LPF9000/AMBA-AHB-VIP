// Scenario builders own transaction intent. They contain no signal access.
class amba_ahb_lite_tb_scenario_seq extends amba_ahb_base_seq;
    `uvm_object_utils(amba_ahb_lite_tb_scenario_seq)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_sequencer m_sqr;

    function new(string name = "amba_ahb_lite_tb_scenario_seq");
        super.new(name);
    endfunction

    task transfer(ahb_addr_t addr, bit write_access, ahb_hsize_e size,
                    ahb_data_t data, bit counts_as_completion = 1'b1);
        amba_ahb_item item;
        item = amba_ahb_item::type_id::create("item");
        start_item(item);
        item.addr = addr;
        item.write = write_access;
        item.size = size;
        item.wdata = data;
        if (counts_as_completion)
            cfg.expected_completions++;
        finish_item(item);
    endtask

    task body();
        m_sqr = p_sequencer;
        if (cfg.scenario == TB_IDLE) begin
            // Idle requests bracket real traffic. Irrelevant, unsupported payload
            // fields must not turn IDLE into a rejected or completed transfer.
            repeat (tb_idle_requests) begin
                amba_ahb_item idle = amba_ahb_item::type_id::create("idle");
                start_item(idle);
                idle.trans = AHB_IDLE;
                idle.addr = (cfg.base_addr + 1);
                idle.size = AHB_DWORD;
                idle.write = 1'b1;
                idle.wdata = tb_abort_data;
                cfg.expected_idle_results++;
                finish_item(idle);
                transfer(cfg.base_addr, 1'b1, AHB_WORD, cfg.transfer_data);
                transfer(cfg.base_addr, 1'b0, AHB_WORD, '0);
            end
        end else if (cfg.reset_on_transfer || cfg.reset_before_accept || cfg.expected_timeouts != 0) begin
            if (cfg.scenario == TB_RESET_RETAIN)
                transfer((cfg.base_addr + ahb_data_bytes), 1'b1, AHB_WORD, cfg.retained_data);
            transfer(cfg.base_addr, cfg.scenario != TB_RESET_READ, AHB_WORD, tb_abort_data, 1'b0);
            cfg.recovery_ready.wait_on();
            transfer(cfg.base_addr, 1'b0, AHB_WORD, '0);
            if (cfg.scenario == TB_RESET_RETAIN)
                transfer((cfg.base_addr + ahb_data_bytes), 1'b0, AHB_WORD, '0);
            transfer((cfg.base_addr + ahb_data_bytes), 1'b1, AHB_WORD, cfg.transfer_data);
            transfer((cfg.base_addr + ahb_data_bytes), 1'b0, AHB_WORD, '0);
        end else if (cfg.scenario inside {TB_LANES, TB_SLAVE_LANES}) begin
            transfer(cfg.base_addr, 1'b1, AHB_WORD, tb_lane_data);
            for (int unsigned lane = 0; lane < ahb_data_bytes; lane++) begin
                transfer(cfg.base_addr + lane, 1'b0, AHB_BYTE, '0);
                transfer(cfg.base_addr + lane, 1'b1, AHB_BYTE, tb_byte_data + lane);
                transfer(cfg.base_addr, 1'b0, AHB_WORD, '0);
            end
            for (int unsigned lane = 0; lane < ahb_data_bytes; lane += ahb_size_bytes(AHB_HWORD)) begin
                transfer(cfg.base_addr + lane, 1'b0, AHB_HWORD, '0);
                transfer(cfg.base_addr + lane, 1'b1, AHB_HWORD, tb_halfword_data + lane);
                transfer(cfg.base_addr, 1'b0, AHB_WORD, '0);
            end
        end else if (cfg.scenario == TB_BASE_SEQ) begin
            amba_ahb_single_seq single_seq;
            single_seq = amba_ahb_single_seq::type_id::create("single_seq");
            single_seq.addr = cfg.base_addr;
            single_seq.size = AHB_WORD;
            single_seq.write = 1'b1;
            single_seq.wdata = cfg.transfer_data;
            if (cfg.randomize_sequences && (single_seq.randomize() with {
                addr == cfg.base_addr;
                size == AHB_WORD;
                write == 1;
            } != 1))
                `uvm_fatal("AHB_RANDOMIZE", "Child single sequence randomization failed")
            cfg.expected_completions++;
            single_seq.start(m_sqr, this);
            single_seq.write = 1'b0;
            cfg.expected_completions++;
            single_seq.start(m_sqr, this);
        end else if (cfg.scenario == TB_SERIAL_BURSTS) begin
            for (int unsigned kind = 1; kind < 8; kind++) begin
                amba_ahb_burst_seq burst_seq;
                int unsigned beats;
                burst_seq = amba_ahb_burst_seq::type_id::create("burst_seq");
                burst_seq.addr = cfg.burst_addr;
                burst_seq.write = 1'b1;
                burst_seq.size = AHB_WORD;
                burst_seq.burst = ahb_hburst_e'(kind);
                burst_seq.incr_length = tb_incr_beats;
                beats = ahb_burst_length(burst_seq.burst);
                if (beats == 0)
                    beats = tb_incr_beats;
                if (cfg.randomize_sequences && (burst_seq.randomize() with {
                    addr == cfg.burst_addr;
                    write == 1;
                    size == AHB_WORD;
                    burst == ahb_hburst_e'(kind);
                    incr_length == tb_incr_beats;
                } != 1))
                    `uvm_fatal("AHB_RANDOMIZE", "Child burst sequence randomization failed")
                burst_seq.data = new[beats];
                foreach (burst_seq.data[i])
                    burst_seq.data[i] = tb_serial_data + ahb_data_t'(i);
                cfg.expected_completions += beats;
                burst_seq.start(m_sqr, this);
                transfer(cfg.burst_addr, 1'b0, AHB_WORD, '0);
            end
        end else if (cfg.scenario == TB_REJECT) begin
            amba_ahb_item item;
            transfer((cfg.base_addr + 1), 1'b1, AHB_WORD, '0, 1'b0);
            transfer(cfg.base_addr, 1'b1, AHB_DWORD, '0, 1'b0);
            item = amba_ahb_item::type_id::create("bad_seq");
            start_item(item);
            item.trans = AHB_SEQ;
            finish_item(item);
            transfer(cfg.base_addr, 1'b1, AHB_WORD, cfg.transfer_data);
            transfer(cfg.base_addr, 1'b0, AHB_WORD, '0);
        end else if (cfg.scenario inside {TB_RANDOM, TB_SLAVE_RANDOM}) begin
            repeat (tb_random_transfers) begin
                amba_ahb_item item;
                item = amba_ahb_item::type_id::create("random_item");
                start_item(item);
                if (cfg.randomize_sequences) begin
                    if (item.randomize() with {
                        addr >= cfg.base_addr;
                        addr < cfg.base_addr + tb_random_addr_span;
                        mastlock == 0;
                    } != 1)
                        `uvm_fatal("AHB_RANDOMIZE", "AHB transaction randomization failed")
                end else begin
                    item.addr = cfg.base_addr;
                    item.size = AHB_WORD;
                    item.write = 1'b1;
                    item.wdata = cfg.transfer_data;
                end
                cfg.expected_completions++;
                finish_item(item);
            end
        end else begin
            transfer(cfg.base_addr, 1'b1, AHB_WORD, cfg.transfer_data);
            transfer(cfg.base_addr, 1'b0, AHB_WORD, '0);
        end
    endtask
endclass
