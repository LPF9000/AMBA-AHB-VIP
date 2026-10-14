class amba_ahb_sequencer extends uvm_sequencer #(amba_ahb_item);
    `uvm_component_utils(amba_ahb_sequencer)
    amba_ahb_agent_cfg cfg;

    function new(string name = "amba_ahb_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_agent_cfg)::get(this, "", "cfg", cfg) || cfg == null)
            `uvm_fatal("AHB_CFG", "Sequencer requires typed agent configuration")
    endfunction
endclass
