`uvm_analysis_imp_decl(_checker_cycle)
`uvm_analysis_imp_decl(_checker_reset)

class amba_ahb_protocol_violation extends uvm_object;
    `uvm_object_utils(amba_ahb_protocol_violation)
    string message;
    int unsigned reset_generation;
    time timestamp;

    function new(string name = "amba_ahb_protocol_violation");
        super.new(name);
    endfunction
endclass
