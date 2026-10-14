// The standard proxy is not a uvm_object, so it has no factory registration.
class amba_ahb_lite_bridge_proxy extends amba_ahb_lite_ms_proxy;
    function new(string name = "amba_ahb_lite_bridge_proxy");
        super.new(name);
    endfunction

    function string get_abstraction();
        return core.get_abstraction();
    endfunction
endclass
