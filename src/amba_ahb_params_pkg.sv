package amba_ahb_params_pkg;
    timeunit 1ns;
    timeprecision 1ps;
    // Compiled baseline. Other widths and profiles require separate qualification.
    parameter int unsigned ahb_lite_addr_width = 32;
    parameter int unsigned ahb_lite_data_width = 32;
    parameter int unsigned ahb_addr_width = ahb_lite_addr_width;
    parameter int unsigned ahb_data_width = ahb_lite_data_width;
    localparam int unsigned ahb_byte_bits = 8;
    localparam int unsigned ahb_data_bytes = ahb_data_width / ahb_byte_bits;
    localparam int unsigned ahb_burst4_beats = 4;
    localparam int unsigned ahb_burst8_beats = 8;
    localparam int unsigned ahb_burst16_beats = 16;
    localparam int unsigned ahb_burst_boundary_bytes = 1024;
    parameter int unsigned ahb_default_incr_limit = ahb_burst_boundary_bytes / ahb_data_bytes;
    localparam logic [3:0] ahb_default_prot = 4'b0011;
    // Coverage policy; the long-wait bucket starts after this many cycles.
    parameter int unsigned ahb_coverage_wait_limit = 16;
    typedef logic [ahb_addr_width-1:0] ahb_addr_t;
    typedef logic [ahb_data_width-1:0] ahb_data_t;
    typedef enum int unsigned {AHB_PROFILE_AMBA3_LITE} ahb_profile_e;
    parameter ahb_profile_e ahb_compiled_profile = AHB_PROFILE_AMBA3_LITE;
    parameter string ahb_spec_revision = "ARM IHI 0033A";

    typedef enum logic [1:0] {
        AHB_IDLE   = 2'b00,
        AHB_BUSY   = 2'b01,
        AHB_NONSEQ = 2'b10,
        AHB_SEQ    = 2'b11
    } ahb_htrans_e;

    typedef enum logic [2:0] {
        AHB_SINGLE = 3'b000,
        AHB_INCR   = 3'b001,
        AHB_WRAP4  = 3'b010,
        AHB_INCR4  = 3'b011,
        AHB_WRAP8  = 3'b100,
        AHB_INCR8  = 3'b101,
        AHB_WRAP16 = 3'b110,
        AHB_INCR16 = 3'b111
    } ahb_hburst_e;

    typedef enum logic [2:0] {
        AHB_BYTE   = 3'b000,
        AHB_HWORD  = 3'b001,
        AHB_WORD   = 3'b010,
        AHB_DWORD  = 3'b011,
        AHB_4WORD  = 3'b100,
        AHB_8WORD  = 3'b101,
        AHB_16WORD = 3'b110,
        AHB_32WORD = 3'b111
    } ahb_hsize_e;

    typedef enum logic {
        AHB_OKAY  = 1'b0,
        AHB_ERROR = 1'b1
    } ahb_hresp_e;

    typedef enum {AHB_MASTER, AHB_SLAVE} ahb_vip_role_e;

    function automatic int unsigned ahb_size_bytes(ahb_hsize_e size);
        if ($isunknown(size))
            return 0;
        return (1 << int'(size));
    endfunction

    function automatic bit ahb_size_supported(ahb_hsize_e size,
            int unsigned data_width);
        return !$isunknown(size) && (ahb_size_bytes(size) != 0) &&
            (ahb_size_bytes(size) <= (data_width / ahb_byte_bits));
    endfunction

    function automatic int unsigned ahb_burst_length(ahb_hburst_e burst);
        case (burst)
            AHB_SINGLE: return 1;
            AHB_INCR4, AHB_WRAP4: return ahb_burst4_beats;
            AHB_INCR8, AHB_WRAP8: return ahb_burst8_beats;
            AHB_INCR16, AHB_WRAP16: return ahb_burst16_beats;
            default: return 0; // Undefined-length INCR is selected by the sequence.
        endcase
    endfunction

    function automatic bit ahb_is_wrapping(ahb_hburst_e burst);
        return burst inside {AHB_WRAP4, AHB_WRAP8, AHB_WRAP16};
    endfunction

endpackage
