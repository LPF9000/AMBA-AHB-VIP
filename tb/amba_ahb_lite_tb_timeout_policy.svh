class amba_ahb_lite_tb_timeout_policy extends uvm_report_catcher;
    `uvm_object_utils(amba_ahb_lite_tb_timeout_policy)
    amba_ahb_lite_tb_cfg cfg;
    function new(string name = "amba_ahb_lite_tb_timeout_policy");
        super.new(name);
    endfunction
    function action_e catch();
        if (get_severity() == UVM_ERROR && get_id() == "AHB_TIMEOUT" &&
                cfg.timeout_reports < cfg.expected_timeouts) begin
            cfg.timeout_reports++;
            return CAUGHT;
        end
        if (get_severity() == UVM_ERROR && get_id() == "AHB_ITEM" &&
                cfg.reject_reports < cfg.expected_rejects) begin
            cfg.reject_reports++;
            return CAUGHT;
        end
        return THROW;
    endfunction
endclass
