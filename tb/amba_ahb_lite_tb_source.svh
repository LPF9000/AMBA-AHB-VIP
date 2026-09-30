// Independent testbench pipelined source. It does not use the VIP master BFM.
class amba_ahb_lite_tb_source extends uvm_driver #(amba_ahb_lite_tb_batch_item);
    `uvm_component_utils(amba_ahb_lite_tb_source)
    amba_ahb_lite_tb_cfg cfg;
    uvm_analysis_port #(amba_ahb_lite_item) request_ap;

    function new(string name = "amba_ahb_lite_tb_source", uvm_component parent = null);
        super.new(name, parent);
        request_ap = new("request_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        amba_ahb_lite_tb_batch_item batch;
        amba_ahb_lite_item data_phase;
        amba_ahb_lite_item intent;
        int unsigned index;
        bit announced;
        cfg.vif.master_idle();
        forever begin
            seq_item_port.get_next_item(batch);
            wait (cfg.vif.HRESETn === 1'b1);
            index = 0;
            data_phase = null;
            announced = 1'b0;
            while (index < batch.transfers.size() || data_phase != null) begin
                @(cfg.vif.master_drive_cb);
                if (index < batch.transfers.size()) begin
                    cfg.vif.master_drive_cb.HADDR <= batch.transfers[index].addr;
                    cfg.vif.master_drive_cb.HWRITE <= batch.transfers[index].write;
                    cfg.vif.master_drive_cb.HTRANS <= batch.transfers[index].trans;
                    cfg.vif.master_drive_cb.HSIZE <= batch.transfers[index].size;
                    cfg.vif.master_drive_cb.HBURST <= batch.transfers[index].burst;
                    cfg.vif.master_drive_cb.HPROT <= batch.transfers[index].prot;
                    cfg.vif.master_drive_cb.HMASTLOCK <= batch.transfers[index].mastlock;
                    if (!announced && (batch.transfers[index].trans inside {AHB_NONSEQ, AHB_SEQ})) begin
                        intent = amba_ahb_lite_item::type_id::create("intent");
                        intent.copy(batch.transfers[index]);
                        request_ap.write(intent);
                    end
                    announced = 1'b1;
                end else begin
                    cfg.vif.master_drive_cb.HTRANS <= AHB_IDLE;
                end
                cfg.vif.master_drive_cb.HWDATA <= data_phase == null ? '0 :
                    data_phase.wdata << (int'(data_phase.addr[1:0]) * 8);
                @(cfg.vif.master_sample_cb);
                if (!cfg.vif.master_sample_cb.HRESETn)
                    `uvm_fatal("AHB_SOURCE", "Unexpected reset in pipeline-only source scenario")
                if (cfg.vif.master_sample_cb.HREADY) begin
                    data_phase = null;
                    if (index < batch.transfers.size()) begin
                        if (batch.transfers[index].trans inside {AHB_NONSEQ, AHB_SEQ})
                            data_phase = batch.transfers[index];
                        index++;
                        announced = 1'b0;
                    end
                end
            end
            @(cfg.vif.master_drive_cb);
            cfg.vif.master_idle();
            seq_item_port.item_done();
        end
    endtask
endclass
