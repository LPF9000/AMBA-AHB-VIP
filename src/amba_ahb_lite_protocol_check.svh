`timescale 1ns/1ps
// Independently implemented for Arm IHI 0033A, AMBA 3 AHB-Lite.
// This checker covers the supported 32-bit, single-master/selected-slave slice.
`include "known_check.svh"
`include "stable_check.svh"
`SVA_DECLARE_KNOWN_CHECK(amba_ahb_lite_known_data_check, amba_ahb_params_pkg::ahb_data_width)
`SVA_DECLARE_STABLE_CHECK_DIAGNOSTIC(amba_ahb_lite_write_stable_check, amba_ahb_params_pkg::ahb_data_width, "AHB_ASSERT_WAIT_WRITE_DATA")

checker amba_ahb_lite_protocol_check (
    input logic clk_i,
    input logic rst_ni,
    input logic enable_i,
    input amba_ahb_params_pkg::ahb_addr_t haddr_i,
    input logic hwrite_i,
    input logic [1:0] htrans_i,
    input logic [2:0] hsize_i,
    input logic [2:0] hburst_i,
    input logic [3:0] hprot_i,
    input logic hmastlock_i,
    input logic hsel_i,
    input amba_ahb_params_pkg::ahb_data_t hwdata_i,
    input amba_ahb_params_pkg::ahb_data_t hrdata_i,
    input logic hready_i,
    input logic hreadyout_i,
    input logic hresp_i,
    input bit phase_selected,
    input bit phase_active,
    input bit phase_write,
    input amba_ahb_params_pkg::ahb_data_t phase_mask
);
    import amba_ahb_params_pkg::*;
    `SVA_ASSERT_LIFECYCLE(clk_i, rst_ni, enable_i)
    typedef int unsigned count_t;
    bit sampled;
    bit burst_active;
    logic [2:0] burst_kind;
    logic [2:0] burst_size;
    bit burst_write;
    logic [3:0] burst_prot;
    bit burst_lock;
    ahb_addr_t burst_first_address;
    ahb_addr_t next_address;
    int unsigned burst_beats;

    function automatic int unsigned beat_count(input logic [2:0] kind);
        return ahb_burst_length(ahb_hburst_e'(kind));
    endfunction

    function automatic ahb_addr_t following_address(input ahb_addr_t address,
            input logic [2:0] size, input logic [2:0] kind);
        ahb_addr_t candidate;
        int unsigned boundary;
        candidate = address + (ahb_addr_t'(1) << size);
        boundary = kind inside {3'b010, 3'b100, 3'b110} ?
            (beat_count(kind) << size) : 0;
        if (boundary != 0 && candidate / boundary != address / boundary)
            candidate = (address / boundary) * boundary;
        return candidate;
    endfunction

    always_ff @(posedge clk_i or negedge rst_ni or negedge enable_i) begin
        if (!rst_ni || !enable_i) begin
            sampled <= 0;
            burst_active <= 0;
            burst_kind <= '0;
            burst_size <= '0;
            burst_write <= 0;
            burst_prot <= '0;
            burst_lock <= 0;
            burst_first_address <= '0;
            next_address <= '0;
            burst_beats <= 0;
        end else begin
            sampled <= 1;
            if (hready_i) begin
                if (!hsel_i || htrans_i == 2'b00) begin
                    burst_active <= 0;
                end else if (htrans_i == 2'b10) begin
                    burst_active <= hburst_i != 3'b000;
                    burst_kind <= hburst_i;
                    burst_size <= hsize_i;
                    burst_write <= hwrite_i;
                    burst_prot <= hprot_i;
                    burst_lock <= hmastlock_i;
                    burst_first_address <= haddr_i;
                    next_address <= following_address(haddr_i, hsize_i, hburst_i);
                    burst_beats <= 1;
                end else if (htrans_i == 2'b11 && burst_active) begin
                    next_address <= following_address(haddr_i, hsize_i, hburst_i);
                    if (burst_kind != 3'b001) begin
                        burst_beats <= burst_beats + 1;
                        if (burst_beats + 1 == beat_count(burst_kind))
                            burst_active <= 0;
                    end
                end
            end
        end
    end

    let accepted_transfer = hsel_i && hready_i && htrans_i[1];
    let burst_continuation = hsel_i && hready_i &&
        (htrans_i inside {2'b01, 2'b11});
    // An ERROR permits early termination; completing the remaining beats is legal too.
    let error_termination = (phase_active && hresp_i) ||
        (sampled && $past(phase_active && hresp_i && !hready_i));

    a_reset_idle: assert property (@(posedge clk_i)
        enable_i && !rst_ni |-> htrans_i == 2'b00)
        else $error("AHB_ASSERT_RESET_IDLE");
    a_reset_ready: assert property (@(posedge clk_i)
        enable_i && !rst_ni |-> hreadyout_i)
        else $error("AHB_ASSERT_RESET_READY");
    a_known_control: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        !$isunknown({hready_i, hreadyout_i, hresp_i, htrans_i, hsel_i}))
        else $error("AHB_ASSERT_KNOWN_CONTROL");
    a_known_address: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        hsel_i && htrans_i != 2'b00 |->
            !$isunknown({haddr_i, hwrite_i, hsize_i, hburst_i, hprot_i, hmastlock_i}))
        else $error("AHB_ASSERT_KNOWN_ADDRESS");
    a_size: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        accepted_transfer |-> ahb_size_supported(ahb_hsize_e'(hsize_i), ahb_data_width))
        else $error("AHB_ASSERT_SIZE");
    a_alignment: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        accepted_transfer |-> (haddr_i & ((ahb_addr_t'(1) << hsize_i) - 1)) == 0)
        else $error("AHB_ASSERT_ALIGNMENT");

    // HREADY accepts the address phase. Slave outputs belong to the saved data phase.
    a_response_route: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        phase_selected |-> hready_i == hreadyout_i)
        else $error("AHB_ASSERT_RESPONSE_ROUTE");
    a_nontransfer: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        phase_selected && !phase_active |-> hreadyout_i && !hresp_i)
        else $error("AHB_ASSERT_NONTRANSFER");
    a_error_second: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        phase_active && hresp_i && !hreadyout_i |=> hresp_i && hreadyout_i)
        else $error("AHB_ASSERT_ERROR_SECOND");
    a_error_first: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        phase_active && hresp_i && hreadyout_i |->
            sampled && $past(phase_active && hresp_i && !hreadyout_i))
        else $error("AHB_ASSERT_ERROR_FIRST");

    // IHI 0033A 3.6 permits IDLE->NONSEQ and BUSY->SEQ during OKAY waits.
    // An undefined INCR burst also permits BUSY->IDLE/NONSEQ.
    a_wait_type: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        !hready_i && !hresp_i |=>
            ($past(htrans_i) == 2'b00 ? htrans_i inside {2'b00, 2'b10} :
            $past(htrans_i) == 2'b01 ?
                ($past(burst_kind) == 3'b001 || htrans_i inside {2'b01, 2'b11}) :
            htrans_i == $past(htrans_i)))
        else $error("AHB_ASSERT_WAIT_TYPE");
    a_wait_address: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        !hready_i && !hresp_i && htrans_i[1] |=>
            $stable({haddr_i, hwrite_i, hsize_i, hburst_i, hprot_i, hmastlock_i, hsel_i}))
        else $error("AHB_ASSERT_WAIT_ADDRESS");
    a_wait_busy: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        !hready_i && !hresp_i && htrans_i == 2'b01 |=>
            !(htrans_i inside {2'b01, 2'b11}) ||
            $stable({haddr_i, hwrite_i, hsize_i, hburst_i, hprot_i, hmastlock_i, hsel_i}))
        else $error("AHB_ASSERT_WAIT_BUSY");
    a_burst_state: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        burst_continuation |-> burst_active)
        else $error("AHB_ASSERT_BURST_STATE");
    a_burst_control: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        burst_continuation && burst_active |->
            {hwrite_i, hsize_i, hburst_i, hprot_i, hmastlock_i} ==
            {burst_write, burst_size, burst_kind, burst_prot, burst_lock})
        else $error("AHB_ASSERT_BURST_CONTROL");
    a_burst_address: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        burst_continuation && burst_active |-> haddr_i == next_address)
        else $error("AHB_ASSERT_BURST_ADDRESS");
    a_burst_end: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        hready_i && burst_active && burst_kind != 3'b001 &&
            (!hsel_i || htrans_i inside {2'b00, 2'b10}) |-> error_termination)
        else $error("AHB_ASSERT_BURST_EARLY_END");
    a_burst_boundary: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        accepted_transfer && htrans_i == 2'b10 && hburst_i inside {3'b011, 3'b101, 3'b111} |->
            count_t'(haddr_i % ahb_burst_boundary_bytes) + (beat_count(hburst_i) << hsize_i) <= ahb_burst_boundary_bytes)
        else $error("AHB_ASSERT_BURST_START_BOUNDARY");
    a_incr_boundary: assert property (@(posedge clk_i) disable iff (!rst_ni || !enable_i)
        burst_continuation && burst_active && burst_kind[0] |->
            haddr_i / ahb_burst_boundary_bytes == burst_first_address / ahb_burst_boundary_bytes)
        else $error("AHB_ASSERT_BURST_BOUNDARY");
endchecker : amba_ahb_lite_protocol_check
