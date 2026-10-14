virtual class amba_ahb_base_seq extends uvm_sequence #(amba_ahb_item);
    `uvm_declare_p_sequencer(amba_ahb_sequencer)
    protected amba_ahb_agent_cfg agent_cfg;

    function new(string name = "amba_ahb_base_seq");
        super.new(name);
    endfunction

    task pre_start();
        super.pre_start();
        if (p_sequencer == null || p_sequencer.cfg == null)
            `uvm_fatal("AHB_CFG", "AHB sequence requires a configured AHB sequencer")
        agent_cfg = p_sequencer.cfg;
        if (!agent_cfg.validate())
            `uvm_fatal("AHB_CFG", "AHB sequence received invalid agent configuration")
    endtask

    // Common intent construction; response handling and bus timing stay in drivers.
    function amba_ahb_item make_transfer(string name, ahb_addr_t addr,
            bit write_access, ahb_hsize_e size, ahb_data_t data,
            ahb_htrans_e trans = AHB_NONSEQ, ahb_hburst_e burst = AHB_SINGLE);
        amba_ahb_item req = amba_ahb_item::type_id::create(name);
        req.addr = addr;
        req.write = write_access;
        req.size = size;
        req.wdata = data;
        req.trans = trans;
        req.burst = burst;
        return req;
    endfunction
endclass : amba_ahb_base_seq
