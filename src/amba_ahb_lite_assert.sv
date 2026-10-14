`include "amba_ahb_lite_protocol_check.svh"
// Pin-level checks for the supported ARM IHI 0033A profile.
module amba_ahb_lite_assert #(
    parameter int unsigned addr_width = amba_ahb_params_pkg::ahb_addr_width,
    parameter int unsigned data_width = amba_ahb_params_pkg::ahb_data_width
) (
    input logic clk_i,
    input logic rst_ni,
    input logic enable_i,
    input logic [addr_width-1:0] haddr_i,
    input logic hwrite_i,
    input logic [1:0] htrans_i,
    input logic [2:0] hsize_i,
    input logic [2:0] hburst_i,
    input logic [3:0] hprot_i,
    input logic hmastlock_i,
    input logic hsel_i,
    input logic [data_width-1:0] hwdata_i,
    input logic [data_width-1:0] hrdata_i,
    input logic hready_i,
    input logic hreadyout_i,
    input logic hresp_i
);
    timeunit 1ns;
    timeprecision 1ps;
    import amba_ahb_params_pkg::*;
    bit phase_selected;
    bit phase_active;
    bit phase_write;
    ahb_data_t phase_mask;

    function automatic ahb_data_t lane_mask(input ahb_addr_t address,
            input logic [2:0] size);
        ahb_data_t mask;
        mask = '0;
        for (int unsigned lane = 0; lane < ahb_data_bytes; lane++) begin
            if (ahb_size_supported(ahb_hsize_e'(size), ahb_data_width) && lane >= (address % ahb_data_bytes) &&
                    lane < (address % ahb_data_bytes) + unsigned'(1 << size))
                mask[lane * ahb_byte_bits +: ahb_byte_bits] = '1;
        end
        return mask;
    endfunction

    // One passive phase decoder feeds the protocol and reusable data checkers.
    always_ff @(posedge clk_i or negedge rst_ni or negedge enable_i) begin
        if (!rst_ni || !enable_i) begin
            phase_selected <= 0;
            phase_active <= 0;
            phase_write <= 0;
            phase_mask <= '0;
        end else if (hready_i) begin
            phase_selected <= hsel_i;
            phase_active <= hsel_i && htrans_i[1];
            phase_write <= hwrite_i;
            phase_mask <= lane_mask(haddr_i, hsize_i);
        end
    end

    initial begin
        if (addr_width != ahb_lite_addr_width || data_width != ahb_lite_data_width)
            $fatal(1, "AHB_ASSERT_UNSUPPORTED_WIDTH");
    end

    amba_ahb_lite_protocol_check protocol_check (
        .clk_i(clk_i), .rst_ni(rst_ni), .enable_i(enable_i),
        .haddr_i(haddr_i), .hwrite_i(hwrite_i), .htrans_i(htrans_i),
        .hsize_i(hsize_i), .hburst_i(hburst_i), .hprot_i(hprot_i),
        .hmastlock_i(hmastlock_i), .hsel_i(hsel_i),
        .hwdata_i(hwdata_i), .hrdata_i(hrdata_i),
        .hready_i(hready_i), .hreadyout_i(hreadyout_i), .hresp_i(hresp_i),
        .phase_selected(phase_selected), .phase_active(phase_active),
        .phase_write(phase_write), .phase_mask(phase_mask)
    );
    amba_ahb_lite_known_data_check known_write_data (
        clk_i, rst_ni, enable_i && phase_active && phase_write, hwdata_i, phase_mask
    );
    amba_ahb_lite_known_data_check known_read_data (
        clk_i, rst_ni, enable_i && phase_active && !phase_write && hready_i && !hresp_i,
        hrdata_i, phase_mask
    );
    amba_ahb_lite_write_stable_check stable_write_data (
        clk_i, rst_ni, enable_i, phase_active && phase_write && !hready_i,
        hwdata_i, phase_mask
    );

endmodule : amba_ahb_lite_assert
