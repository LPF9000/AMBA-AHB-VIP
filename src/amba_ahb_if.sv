// AMBA 3 AHB-Lite signal interface.
//
// The initial VIP supports a single master and a single selected slave.  HSEL
// is included for slave-side integrations where the DUT supplies decoding; it
// is not driven by the master driver.
interface amba_ahb_if #(
    parameter int unsigned ADDR_WIDTH = amba_ahb_params_pkg::ahb_addr_width,
    parameter int unsigned DATA_WIDTH = amba_ahb_params_pkg::ahb_data_width
) (
    input logic HCLK,
    input logic HRESETn
);

    timeunit 1ns;
    timeprecision 1ps;
    import amba_ahb_params_pkg::*;

    logic [ADDR_WIDTH-1:0] HADDR;
    logic                  HWRITE;
    logic [1:0]            HTRANS;
    logic [2:0]            HSIZE;
    logic [2:0]            HBURST;
    logic [3:0]            HPROT;
    logic                  HMASTLOCK;
    logic                  HSEL;
    logic [DATA_WIDTH-1:0] HWDATA;
    logic [DATA_WIDTH-1:0] HRDATA;
    logic                  HREADY;
    logic                  HREADYOUT;
    logic                  HRESP;

    // These modports document direction at the integration boundary.  The
    // monitor intentionally has read-only access to every protocol signal.
    modport master (
        input  HCLK, HRESETn, HRDATA, HREADY, HRESP,
        output HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HMASTLOCK, HWDATA
    );

    modport slave (
        input  HCLK, HRESETn, HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT,
                        HMASTLOCK, HSEL, HWDATA, HREADY,
        output HRDATA, HREADYOUT, HRESP
    );

    modport monitor (
        input HCLK, HRESETn, HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT,
                    HMASTLOCK, HSEL, HWDATA, HRDATA, HREADY, HREADYOUT, HRESP
    );

    // Separate clocking views avoid races between DUT nonblocking assignments,
    // driver outputs, and monitor samples. HREADY is global/interconnect-owned;
    // HREADYOUT is the selected subordinate's response and is never composed
    // here by the responder BFM.
    // Drive the next cycle after the rising-edge sample, using Re-NBA output
    // scheduling. Input #1step retains the values that the DUT saw at the edge.
    clocking master_drive_cb @(posedge HCLK);
        default input #1step output #0;
        output HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HMASTLOCK, HWDATA;
    endclocking

    clocking master_sample_cb @(posedge HCLK);
        default input #1step;
        input HRESETn, HRDATA, HREADY, HRESP;
    endclocking

    clocking slave_drive_cb @(posedge HCLK);
        default input #1step output #0;
        output HREADYOUT, HRDATA, HRESP;
    endclocking

    clocking monitor_cb @(posedge HCLK);
        default input #1step;
        input HRESETn, HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT,
                    HMASTLOCK, HSEL, HWDATA, HRDATA, HREADY, HREADYOUT, HRESP;
    endclocking

    // Pin-level master BFM primitives.  The UVM driver owns transaction intent;
    // these tasks own only clocked pin manipulation and completion sampling.
    // The linter reports INITIALDLY when a clocking-block output is assigned by
    // a standalone initial smoke task. Runtime UVM drivers use these assignments
    // from run_phase; the narrow waiver avoids changing race-free NBA semantics.
    /* verilator lint_off INITIALDLY */
    task automatic master_reset_idle();
        HADDR <= '0;
        HWRITE <= 1'b0;
        HTRANS <= 2'b00;
        HSIZE <= 3'b010;
        HBURST <= 3'b000;
        HPROT <= ahb_default_prot;
        HMASTLOCK <= 1'b0;
        HWDATA <= '0;
        // Keep clocking output state synchronized with the asynchronous pins.
        master_idle();
    endtask

    task automatic slave_reset_ready();
        HREADYOUT <= 1'b1;
        HRESP <= 1'b0;
        HRDATA <= '0;
        slave_drive_cb.HREADYOUT <= 1'b1;
        slave_drive_cb.HRESP <= 1'b0;
        slave_drive_cb.HRDATA <= '0;
    endtask

    task automatic master_idle();
        master_drive_cb.HADDR     <= '0;
        master_drive_cb.HWRITE    <= 1'b0;
        master_drive_cb.HTRANS    <= 2'b00;
        master_drive_cb.HSIZE     <= 3'b010;
        master_drive_cb.HBURST    <= 3'b000;
        master_drive_cb.HPROT     <= ahb_default_prot;
        master_drive_cb.HMASTLOCK <= 1'b0;
        master_drive_cb.HWDATA    <= '0;
    endtask

    logic [ADDR_WIDTH-1:0] launch_addr;
    logic [2:0] launch_size;
    logic [2:0] launch_burst;
    bit launch_accepted;
    int unsigned reset_generation = 0;
    always @(negedge HRESETn) reset_generation++;

    task automatic master_drive(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic                  write,
        input logic [1:0]            trans,
        input logic [2:0]            size,
        input logic [2:0]            burst,
        input logic [3:0]            prot,
        input logic                  lock,
        input logic [DATA_WIDTH-1:0] wdata
    );
        // Launch after this edge; address acceptance is sampled at a subsequent
        // rising edge. Clocking outputs cannot replace the DUT's current sample.
        @(master_drive_cb);
        if (!HRESETn) begin
            master_reset_idle();
        end else begin
            launch_addr = addr;
            launch_size = size;
            launch_burst = burst;
            master_drive_cb.HADDR     <= addr;
            master_drive_cb.HWRITE    <= write;
            master_drive_cb.HTRANS    <= trans;
            master_drive_cb.HSIZE     <= size;
            master_drive_cb.HBURST    <= burst;
            master_drive_cb.HPROT     <= prot;
            master_drive_cb.HMASTLOCK <= lock;
            master_drive_cb.HWDATA    <= wdata << (int'(addr % (DATA_WIDTH / ahb_byte_bits)) * ahb_byte_bits);
        end
    endtask
    /* verilator lint_on INITIALDLY */

    task automatic master_complete(
        input  bit                     write,
        input  logic [DATA_WIDTH-1:0]  wdata,
        input  int unsigned max_wait_cycles,
        output logic [DATA_WIDTH-1:0] rdata,
        output ahb_hresp_e             resp,
        output int unsigned           wait_cycles,
        output bit                     completed,
        output bit                     reset_abort,
        output bit                     timed_out,
        input logic [1:0]               next_trans = 2'b00
    );
        int unsigned launch_reset_generation;
        launch_reset_generation = reset_generation;
        launch_accepted = 1'b0;
        rdata       = '0;
        resp        = AHB_OKAY;
        wait_cycles = 0;
        completed   = 1'b0;
        reset_abort = 1'b0;
        timed_out   = 1'b0;

        // The first sampled edge is the address phase.  AHB completion is
        // sampled in the following data phase, so do not mistake the address
        // phase's normally-high HREADY for completion of this transfer.
        do begin
            @(master_sample_cb);
            if (!master_sample_cb.HRESETn || reset_generation != launch_reset_generation) begin
                reset_abort = 1'b1;
                master_reset_idle();
                return;
            end
            if (!master_sample_cb.HREADY) begin
                wait_cycles++;
                if ((max_wait_cycles != 0) && (wait_cycles >= max_wait_cycles)) begin
                    timed_out = 1'b1;
                    master_idle();
                    return;
                end
            end
        end while (!master_sample_cb.HREADY);

        launch_accepted = 1'b1;
        // The accepted address is no longer presented as a new transfer.
        // Preserve write data while its data phase waits. BUSY bridges burst beats.
        // We are already synchronized to the accepting rising edge. Drive its
        // following cycle now; waiting for another drive event adds a cycle.
        master_drive_cb.HTRANS <= next_trans;
        if (next_trans == 2'b01) begin
            logic [ADDR_WIDTH-1:0] candidate;
            int unsigned boundary;
            candidate = launch_addr + (1 << launch_size);
            boundary = (launch_burst inside {3'b010, 3'b100, 3'b110}) ?
                ((launch_burst == 3'b010 ? 4 : launch_burst == 3'b100 ? 8 : 16) << launch_size) : 0;
            if ((boundary != 0) && ((candidate / boundary) != (launch_addr / boundary)))
                candidate = (launch_addr / boundary) * boundary;
            master_drive_cb.HADDR <= candidate;
        end

        forever begin
            @(master_sample_cb);
            if (!master_sample_cb.HRESETn || reset_generation != launch_reset_generation) begin
                reset_abort = 1'b1;
                master_reset_idle();
                return;
            end
            if (master_sample_cb.HREADY) begin
                rdata = master_sample_cb.HRDATA >> (int'(launch_addr % (DATA_WIDTH / ahb_byte_bits)) * ahb_byte_bits);
                if (int'(launch_size) < $clog2(DATA_WIDTH / ahb_byte_bits))
                    rdata &= (DATA_WIDTH'(1) << ((1 << launch_size) * ahb_byte_bits)) - 1;
                resp      = ahb_hresp_e'(master_sample_cb.HRESP);
                completed = 1'b1;
                if (next_trans == 2'b00)
                    master_idle();
                return;
            end
            wait_cycles++;
            if ((max_wait_cycles != 0) && (wait_cycles >= max_wait_cycles)) begin
                timed_out = 1'b1;
                master_idle();
                return;
            end
        end
    endtask

endinterface
