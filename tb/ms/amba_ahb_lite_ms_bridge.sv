`ifdef AHB_UVM_MS
// UVM-MS 1.0 clauses 4.2 and 5: external SV interface, proxy, and bridge core.
// The local simulator lacks interconnect; only its digital test view uses wire ports.
`ifdef VERILATOR
`define AHB_MS_NET wire
`else
`define AHB_MS_NET interconnect
`endif
module amba_ahb_lite_ms_bridge (
    amba_ahb_if bus,
    output `AHB_MS_NET [amba_ahb_params_pkg::ahb_addr_width-1:0] addr,
    output `AHB_MS_NET  write,
    output `AHB_MS_NET [1:0] trans,
    output `AHB_MS_NET [2:0] size,
    output `AHB_MS_NET [2:0] burst,
    output `AHB_MS_NET [3:0] prot,
    output `AHB_MS_NET  mastlock,
    output `AHB_MS_NET [amba_ahb_params_pkg::ahb_data_width-1:0] wdata,
    output `AHB_MS_NET  selected,
    output `AHB_MS_NET  ready,
    input `AHB_MS_NET  readyout,
    input `AHB_MS_NET  resp,
    input `AHB_MS_NET [amba_ahb_params_pkg::ahb_data_width-1:0] rdata
);
    timeunit 1ns;
    timeprecision 1ps;
    import uvm_pkg::*;
    import uvm_ms_pkg::*;
    import amba_ahb_lite_ms_pkg::*;
    `include "uvm_macros.svh"
    `include "uvm_ms_includes.svh"
    `include "ms/amba_ahb_lite_bridge_proxy.svh"
    amba_ahb_lite_bridge_proxy proxy = new("proxy");
    amba_ahb_lite_ms_core core (
        .addr(addr),
        .write(write),
        .trans(trans),
        .size(size),
        .burst(burst),
        .prot(prot),
        .mastlock(mastlock),
        .wdata(wdata),
        .selected(selected),
        .ready(ready),
        .readyout(readyout),
        .resp(resp),
        .rdata(rdata)
    );
    assign core.addr_value = bus.HADDR;
    assign core.write_value = bus.HWRITE;
    assign core.trans_value = bus.HTRANS;
    assign core.size_value = bus.HSIZE;
    assign core.burst_value = bus.HBURST;
    assign core.prot_value = bus.HPROT;
    assign core.mastlock_value = bus.HMASTLOCK;
    assign core.wdata_value = bus.HWDATA;
    assign core.selected_value = bus.HSEL;
    assign core.ready_value = bus.HREADY;
    assign bus.HREADYOUT = core.readyout_value;
    assign bus.HRESP = core.resp_value;
    assign bus.HRDATA = core.rdata_value;
endmodule
`undef AHB_MS_NET
`endif
