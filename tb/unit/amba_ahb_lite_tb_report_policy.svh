// Report expectation policy belongs to a protocol_checker component, never a UVM test.
class amba_ahb_lite_tb_report_policy extends uvm_report_catcher;
    `uvm_object_utils(amba_ahb_lite_tb_report_policy)
    int unsigned expected[string];
    int unsigned caught[string];

    function new(string name = "amba_ahb_lite_tb_report_policy");
        super.new(name);
    endfunction

    function action_e catch();
        foreach (expected[key]) begin
            if (get_severity() == UVM_ERROR &&
                    uvm_is_match(key, {get_id(), ":", get_message()})) begin
                caught[key]++;
                return CAUGHT;
            end
        end
        return THROW;
    endfunction
endclass
