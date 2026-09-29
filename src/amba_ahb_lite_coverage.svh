class amba_ahb_lite_coverage extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_coverage)
    ahb_hsize_e size_sample;
    ahb_hburst_e burst_sample;
    ahb_hresp_e resp_sample;
    bit write_sample;
    int unsigned wait_sample;

    /* verilator lint_off COVERIGN */
    covergroup transfer_cg;
        cp_size: coverpoint size_sample;
        cp_burst: coverpoint burst_sample;
        cp_resp: coverpoint resp_sample;
        cp_write: coverpoint write_sample;
        cp_wait: coverpoint wait_sample { bins no_wait = {0}; bins waited = {[1:16]}; bins long_wait = {[17:$]}; }
        size_x_resp: cross cp_size, cp_resp;
    endgroup
    /* verilator lint_on COVERIGN */

    function new(string name = "amba_ahb_lite_coverage", uvm_component parent = null);
        super.new(name, parent);
        transfer_cg = new();
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        size_sample = item.size;
        burst_sample = item.burst;
        resp_sample = item.resp;
        write_sample = item.write;
        wait_sample = item.wait_cycles;
        transfer_cg.sample();
    endfunction
endclass
