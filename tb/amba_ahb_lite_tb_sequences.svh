// Scenario builders own transaction intent. They contain no signal access.
class amba_ahb_lite_tb_scenario_seq extends uvm_sequence #(amba_ahb_lite_item);
    `uvm_object_utils(amba_ahb_lite_tb_scenario_seq)
    amba_ahb_lite_tb_cfg cfg;

    function new(string name = "amba_ahb_lite_tb_scenario_seq");
        super.new(name);
    endfunction

    task transfer(logic [31:0] addr, bit write_access, ahb_hsize_e size,
                  logic [31:0] data, bit counts_as_completion = 1'b1);
        amba_ahb_lite_item item;
        item = amba_ahb_lite_item::type_id::create("item");
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
        if (cfg.reset_on_transfer || cfg.reset_before_accept || cfg.expected_timeouts != 0) begin
            if (cfg.scenario == TB_RESET_RETAIN)
                transfer(32'h104, 1'b1, AHB_WORD, 32'h2468_1357);
            transfer(32'h100, cfg.scenario != TB_RESET_READ, AHB_WORD, 32'hdead_beef, 1'b0);
            cfg.recovery_ready.wait_on();
            transfer(32'h100, 1'b0, AHB_WORD, '0);
            if (cfg.scenario == TB_RESET_RETAIN)
                transfer(32'h104, 1'b0, AHB_WORD, '0);
            transfer(32'h104, 1'b1, AHB_WORD, 32'h1234_abcd);
            transfer(32'h104, 1'b0, AHB_WORD, '0);
        end else if (cfg.scenario inside {TB_LANES, TB_SLAVE_LANES}) begin
            transfer(32'h100, 1'b1, AHB_WORD, 32'h4433_2211);
            for (int unsigned lane = 0; lane < 4; lane++) begin
                transfer(32'h100 + lane, 1'b0, AHB_BYTE, '0);
                transfer(32'h100 + lane, 1'b1, AHB_BYTE, 32'ha0 + lane);
                transfer(32'h100, 1'b0, AHB_WORD, '0);
            end
            for (int unsigned lane = 0; lane < 4; lane += 2) begin
                transfer(32'h100 + lane, 1'b0, AHB_HWORD, '0);
                transfer(32'h100 + lane, 1'b1, AHB_HWORD, 32'hbe00 + lane);
                transfer(32'h100, 1'b0, AHB_WORD, '0);
            end
        end else if (cfg.scenario == TB_SERIAL_BURSTS) begin
            for (int unsigned kind = 1; kind < 8; kind++) begin
                amba_ahb_lite_burst_sequence burst_seq;
                int unsigned beats;
                burst_seq = amba_ahb_lite_burst_sequence::type_id::create("burst_seq");
                burst_seq.addr = 32'h200;
                burst_seq.write = 1'b1;
                burst_seq.size = AHB_WORD;
                burst_seq.burst = ahb_hburst_e'(kind);
                burst_seq.incr_length = 5;
                beats = ahb_burst_length(burst_seq.burst);
                if (beats == 0)
                    beats = 5;
                burst_seq.data = new[beats];
                foreach (burst_seq.data[i])
                    burst_seq.data[i] = 32'h9000 + 32'(i);
                cfg.expected_completions += beats;
                burst_seq.start(m_sequencer, this);
                transfer(32'h200, 1'b0, AHB_WORD, '0);
            end
        end else if (cfg.scenario == TB_REJECT) begin
            amba_ahb_lite_item item;
            transfer(32'h101, 1'b1, AHB_WORD, '0, 1'b0);
            transfer(32'h100, 1'b1, AHB_DWORD, '0, 1'b0);
            item = amba_ahb_lite_item::type_id::create("bad_seq");
            start_item(item);
            item.trans = AHB_SEQ;
            finish_item(item);
            transfer(32'h100, 1'b1, AHB_WORD, 32'h1234_abcd);
            transfer(32'h100, 1'b0, AHB_WORD, '0);
        end else if (cfg.scenario inside {TB_RANDOM, TB_SLAVE_RANDOM}) begin
            repeat (200) begin
                amba_ahb_lite_item item;
                item = amba_ahb_lite_item::type_id::create("random_item");
                start_item(item);
                // Construct only legal values; this seeded generator needs no
                // external SMT solver on the local simulator.
                item.size = ahb_hsize_e'($urandom_range(2, 0));
                item.addr = 32'h100 + ($urandom_range(127, 0) &
                    ~((32'h1 << int'(item.size)) - 1));
                item.write = 1'($urandom_range(1, 0));
                item.wdata = $urandom();
                item.prot = 4'($urandom());
                cfg.expected_completions++;
                finish_item(item);
            end
        end else begin
            transfer(32'h100, 1'b1, AHB_WORD, 32'h1234_abcd);
            transfer(32'h100, 1'b0, AHB_WORD, '0);
        end
    endtask
endclass

class amba_ahb_lite_tb_batch_seq extends uvm_sequence #(amba_ahb_lite_tb_batch_item);
    `uvm_object_utils(amba_ahb_lite_tb_batch_seq)
    amba_ahb_lite_tb_cfg cfg;

    function new(string name = "amba_ahb_lite_tb_batch_seq");
        super.new(name);
    endfunction

    function void add_transfer(amba_ahb_lite_tb_batch_item batch, logic [31:0] addr,
                              bit write_access, logic [31:0] data,
                              ahb_htrans_e trans = AHB_NONSEQ,
                              ahb_hburst_e burst = AHB_SINGLE);
        amba_ahb_lite_item item;
        item = amba_ahb_lite_item::type_id::create("transfer");
        item.addr = addr;
        item.write = write_access;
        item.wdata = data;
        item.trans = trans;
        item.burst = burst;
        item.mastlock = cfg.scenario inside {TB_BURSTS, TB_BURST_ERROR};
        item.prot = 4'b1011;
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
                logic [31:0] addr = 32'h200;
                if (beats == 0)
                    beats = 5;
                if (ahb_is_wrapping(burst))
                    addr += beats * 4 - 4;
                for (int unsigned beat = 0; beat < beats; beat++) begin
                    add_transfer(batch, addr, 1'b1, 32'h1000 + beat,
                        beat == 0 ? AHB_NONSEQ : AHB_SEQ, burst);
                    if (beat == 0)
                        add_transfer(batch, ahb_is_wrapping(burst) ? 32'h200 : addr + 4,
                            1'b1, '0, AHB_BUSY, burst);
                    if (ahb_is_wrapping(burst))
                        addr = 32'h200 + ((addr + 4 - 32'h200) % (beats * 4));
                    else
                        addr += 4;
                end
                add_transfer(batch, '0, 1'b0, '0, AHB_IDLE);
                add_transfer(batch, 32'h200, 1'b0, '0);
            end
        end else begin
            // Identical accepted requests must remain separate transactions.
            add_transfer(batch, 32'h100, 1'b1, 32'h1234_abcd);
            add_transfer(batch, 32'h100, 1'b1, 32'h1234_abcd);
            add_transfer(batch, 32'h104, 1'b1, 32'h5566_7788);
            add_transfer(batch, 32'h100, 1'b0, '0);
            add_transfer(batch, 32'h104, 1'b0, '0);
            add_transfer(batch, 32'h104, 1'b0, '0);
        end
        finish_item(batch);
    endtask
endclass

class amba_ahb_lite_tb_response_seq extends uvm_sequence #(amba_ahb_lite_item);
    `uvm_object_utils(amba_ahb_lite_tb_response_seq)

    function new(string name = "amba_ahb_lite_tb_response_seq");
        super.new(name);
    endfunction

    task body();
        repeat (6) begin
            amba_ahb_lite_item item;
            item = amba_ahb_lite_item::type_id::create("response");
            start_item(item);
            item.wait_cycles = 2;
            finish_item(item);
        end
    endtask
endclass
