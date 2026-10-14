virtual class amba_ahb_lite_ms_proxy extends uvm_ms_pkg::uvm_ms_proxy;
    function new(string name = "amba_ahb_lite_ms_proxy");
        super.new(name);
    endfunction

    pure virtual function string get_abstraction();
endclass
