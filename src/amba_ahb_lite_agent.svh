class amba_ahb_lite_agent extends uvm_agent;
    `uvm_component_utils(amba_ahb_lite_agent)

    amba_ahb_lite_agent_config cfg;
    amba_ahb_lite_sequencer    sequencer;
    amba_ahb_lite_master_driver master_driver;
    amba_ahb_lite_slave_driver  slave_driver;
    amba_ahb_lite_monitor       monitor;
    amba_ahb_lite_protocol_checker protocol_checker;

    function new(string name = "amba_ahb_lite_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(amba_ahb_lite_agent_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("AHB_CFG", "Agent requires amba_ahb_lite_agent_config")
        is_active = cfg.is_active;
        if (cfg.vif == null)
            `uvm_fatal("AHB_VIF", "Agent configuration contains a null virtual interface")
        if (!cfg.validate())
            `uvm_fatal("AHB_CFG", "Invalid AMBA AHB-Lite agent configuration")

        uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "monitor", "cfg", cfg);
        monitor = amba_ahb_lite_monitor::type_id::create("monitor", this);
        if (cfg.checks_enable) begin
            uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "protocol_checker", "cfg", cfg);
            protocol_checker = amba_ahb_lite_protocol_checker::type_id::create("protocol_checker", this);
        end
        if (cfg.is_active == UVM_ACTIVE) begin
            uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "sequencer", "cfg", cfg);
            sequencer = amba_ahb_lite_sequencer::type_id::create("sequencer", this);
            if (cfg.role == AHB_MASTER) begin
                uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "master_driver", "cfg", cfg);
                master_driver = amba_ahb_lite_master_driver::type_id::create("master_driver", this);
            end else begin
                uvm_config_db#(amba_ahb_lite_agent_config)::set(this, "slave_driver", "cfg", cfg);
                slave_driver = amba_ahb_lite_slave_driver::type_id::create("slave_driver", this);
            end
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (protocol_checker != null) begin
            monitor.item_ap.connect(protocol_checker.analysis_export);
            monitor.cycle_ap.connect(protocol_checker.cycle_export);
            monitor.reset_ap.connect(protocol_checker.reset_export);
        end
        if (cfg.is_active == UVM_ACTIVE) begin
            if (cfg.role == AHB_MASTER)
                master_driver.seq_item_port.connect(sequencer.seq_item_export);
            else
                slave_driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass
