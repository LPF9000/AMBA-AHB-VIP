class amba_ahb_lite_scenario_vseq extends uvm_sequence;
    `uvm_object_utils(amba_ahb_lite_scenario_vseq)
    `uvm_declare_p_sequencer(amba_ahb_lite_virtual_sequencer)
    amba_ahb_lite_tb_cfg cfg;
    amba_ahb_sequencer m_sqr;
    rand ahb_data_t transfer_data;

    function new(string name = "amba_ahb_lite_scenario_vseq");
        super.new(name);
        transfer_data = tb_transfer_data;
    endfunction

    task pre_start();
        super.pre_start();
        if (p_sequencer == null || p_sequencer.cfg == null)
            `uvm_fatal("AHB_CFG", "Virtual sequence requires typed testbench sequencer")
        cfg = p_sequencer.cfg;
        m_sqr = p_sequencer.m_sqr;
        cfg.transfer_data = (cfg.scenario inside {TB_RESPONSE_LATE, TB_RESPONSE_EDGE}) ?
            tb_timing_data : transfer_data;
    endtask

    task body();
        amba_ahb_lite_tb_scenario_seq seq;
        amba_ahb_lite_tb_batch_seq batch_seq;
        amba_ahb_lite_tb_response_seq response_seq;
        if (cfg.scenario == TB_TOPOLOGY)
            return;
        if (cfg.use_batch_source) begin
            batch_seq = amba_ahb_lite_tb_batch_seq::type_id::create("batch_seq");
            batch_seq.cfg = cfg;
            if (cfg.scenario == TB_SLAVE_SCRIPT) begin
                response_seq = amba_ahb_lite_tb_response_seq::type_id::create("response_seq");
                fork
                    batch_seq.start(p_sequencer.source_sqr, this);
                    response_seq.start(p_sequencer.slave_sqr, this);
                join
            end else begin
                batch_seq.start(p_sequencer.source_sqr, this);
            end
        end else begin
            if (m_sqr == null)
                `uvm_fatal("AHB_CFG", "Scenario needs an active master sequencer")
            seq = amba_ahb_lite_tb_scenario_seq::type_id::create("seq");
            seq.cfg = cfg;
            seq.start(m_sqr, this);
        end
    endtask
endclass
