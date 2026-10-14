`ifdef AHB_UVM_MS
// Digital core view. Replace this module with an AMS/RNM core of the same API.
module amba_ahb_lite_ms_core (
    output wire [amba_ahb_params_pkg::ahb_addr_width-1:0] addr,
    output wire  write,
    output wire [1:0] trans,
    output wire [2:0] size,
    output wire [2:0] burst,
    output wire [3:0] prot,
    output wire  mastlock,
    output wire [amba_ahb_params_pkg::ahb_data_width-1:0] wdata,
    output wire  selected,
    output wire  ready,
    input wire  readyout,
    input wire  resp,
    input wire [amba_ahb_params_pkg::ahb_data_width-1:0] rdata
);
    timeunit 1ns;
    timeprecision 1ps;
    wire [amba_ahb_params_pkg::ahb_addr_width-1:0] addr_value;
    assign addr = addr_value;
    wire  write_value;
    assign write = write_value;
    wire [1:0] trans_value;
    assign trans = trans_value;
    wire [2:0] size_value;
    assign size = size_value;
    wire [2:0] burst_value;
    assign burst = burst_value;
    wire [3:0] prot_value;
    assign prot = prot_value;
    wire  mastlock_value;
    assign mastlock = mastlock_value;
    wire [amba_ahb_params_pkg::ahb_data_width-1:0] wdata_value;
    assign wdata = wdata_value;
    wire  selected_value;
    assign selected = selected_value;
    wire  ready_value;
    assign ready = ready_value;
    wire  readyout_value = readyout;
    wire  resp_value = resp;
    wire [amba_ahb_params_pkg::ahb_data_width-1:0] rdata_value = rdata;
    function string get_abstraction();
        return "digital";
    endfunction
endmodule
`endif
