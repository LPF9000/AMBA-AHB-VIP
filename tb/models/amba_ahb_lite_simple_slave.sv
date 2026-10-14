// Small independent memory endpoint for digital VIP integration tests.
// This simulation model is a temporary DUT, not production AHB IP.
module amba_ahb_lite_simple_slave (
    input logic clk,
    input logic reset_n,
    input logic selected,
    input logic ready,
    input amba_ahb_params_pkg::ahb_addr_t addr,
    input logic write_access,
    input amba_ahb_params_pkg::ahb_htrans_e trans,
    input amba_ahb_params_pkg::ahb_hsize_e size,
    input amba_ahb_params_pkg::ahb_data_t wdata,
    input int unsigned wait_cycles,
    input bit inject_error,
    input amba_ahb_params_pkg::ahb_addr_t error_addr,
    output logic readyout,
    output amba_ahb_params_pkg::ahb_hresp_e resp,
    output amba_ahb_params_pkg::ahb_data_t rdata
);
    timeunit 1ns;
    timeprecision 1ps;
    import amba_ahb_params_pkg::*;
    logic [ahb_byte_bits-1:0] memory [ahb_addr_t];
    bit pending;
    bit pending_write;
    bit failed;
    bit error_started;
    ahb_addr_t pending_addr;
    int unsigned byte_count;
    int unsigned remaining;
    ahb_data_t read_value;

    initial begin
        readyout = 1'b1;
        resp = AHB_OKAY;
        rdata = '0;
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            memory.delete();
            pending = 1'b0;
            readyout <= 1'b1;
            resp <= AHB_OKAY;
            rdata <= '0;
        end else begin
            if (pending && ready) begin
                if (pending_write && !failed)
                    for (int unsigned i = 0; i < byte_count; i++)
                        memory[pending_addr + i] = wdata[
                            ((int'(pending_addr % ahb_data_bytes) + i) * ahb_byte_bits) +: ahb_byte_bits];
                pending = 1'b0;
            end
            if (ready && selected && trans[1]) begin
                pending = 1'b1;
                pending_addr = addr;
                pending_write = write_access;
                byte_count = 1 << int'(size);
                remaining = wait_cycles;
                failed = inject_error && write_access && addr == error_addr;
                error_started = 1'b0;
            end
            read_value = '0;
            if (pending && !pending_write)
                for (int unsigned i = 0; i < byte_count; i++)
                    if (memory.exists(pending_addr + i))
                        read_value[((int'(pending_addr % ahb_data_bytes) + i) * ahb_byte_bits) +: ahb_byte_bits] =
                            memory[pending_addr + i];
            rdata <= read_value;
            if (!pending) begin
                readyout <= 1'b1;
                resp <= AHB_OKAY;
            end else if (remaining != 0) begin
                remaining--;
                readyout <= 1'b0;
                resp <= AHB_OKAY;
            end else if (failed && !error_started) begin
                error_started = 1'b1;
                readyout <= 1'b0;
                resp <= AHB_ERROR;
            end else begin
                readyout <= 1'b1;
                resp <= failed ? AHB_ERROR : AHB_OKAY;
            end
        end
    end
endmodule
