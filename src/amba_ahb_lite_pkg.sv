package amba_ahb_lite_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

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
        return (1 << int'(size));
    endfunction

    function automatic bit ahb_size_supported(ahb_hsize_e size,
                                                                                          int unsigned data_width);
        return (ahb_size_bytes(size) <= (data_width / 8));
    endfunction

    function automatic int unsigned ahb_burst_length(ahb_hburst_e burst);
        case (burst)
            AHB_SINGLE: return 1;
            AHB_INCR4, AHB_WRAP4: return 4;
            AHB_INCR8, AHB_WRAP8: return 8;
            AHB_INCR16, AHB_WRAP16: return 16;
            default: return 0; // Undefined-length INCR is selected by the sequence.
        endcase
    endfunction

    function automatic bit ahb_is_wrapping(ahb_hburst_e burst);
        return burst inside {AHB_WRAP4, AHB_WRAP8, AHB_WRAP16};
    endfunction

    `include "amba_ahb_lite_item.svh"
    `include "amba_ahb_lite_config.svh"
    `include "amba_ahb_lite_observed_item.svh"
    `include "amba_ahb_lite_reset_event.svh"
    `include "amba_ahb_lite_sequencer.svh"
    `include "amba_ahb_lite_driver.svh"
    `include "amba_ahb_lite_slave_driver.svh"
    `include "amba_ahb_lite_monitor.svh"
    `include "amba_ahb_lite_protocol_checker.svh"
    `include "amba_ahb_lite_agent.svh"
    `include "amba_ahb_lite_env_config.svh"
    `include "amba_ahb_lite_stream_scoreboard.svh"
    `include "amba_ahb_lite_predictor.svh"
    `include "amba_ahb_lite_scoreboard.svh"
    `include "amba_ahb_lite_coverage.svh"
    `include "amba_ahb_lite_env.svh"
    `include "amba_ahb_lite_sequences.svh"
endpackage
