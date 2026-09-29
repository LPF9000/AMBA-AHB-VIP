// AMBA 3 AHB-Lite signal interface.
//
// The initial VIP supports a single master and a single selected slave.  HSEL
// is included for slave-side integrations where the DUT supplies decoding; it
// is not driven by the master driver.
interface amba_ahb_lite_if #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
) (
    input logic HCLK,
    input logic HRESETn
);

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
    clocking master_drive_cb @(negedge HCLK);
        default input #1step output #0;
        output HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HMASTLOCK, HWDATA;
    endclocking

    clocking master_sample_cb @(posedge HCLK);
        default input #1step;
        input HRESETn, HRDATA, HREADY, HRESP;
    endclocking

    clocking slave_drive_cb @(negedge HCLK);
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
    task automatic master_idle();
        master_drive_cb.HADDR     <= '0;
        master_drive_cb.HWRITE    <= 1'b0;
        master_drive_cb.HTRANS    <= 2'b00;
        master_drive_cb.HSIZE     <= 3'b010;
        master_drive_cb.HBURST    <= 3'b000;
        master_drive_cb.HPROT     <= 4'b0011;
        master_drive_cb.HMASTLOCK <= 1'b0;
        master_drive_cb.HWDATA    <= '0;
    endtask

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
        // A transfer is launched in the half-cycle before its address phase is
        // sampled.  The driver therefore cannot race a DUT sampling at posedge.
        @(master_drive_cb);
        if (!HRESETn) begin
            master_idle();
        end else begin
            master_drive_cb.HADDR     <= addr;
            master_drive_cb.HWRITE    <= write;
            master_drive_cb.HTRANS    <= trans;
            master_drive_cb.HSIZE     <= size;
            master_drive_cb.HBURST    <= burst;
            master_drive_cb.HPROT     <= prot;
            master_drive_cb.HMASTLOCK <= lock;
            master_drive_cb.HWDATA    <= wdata;
        end
    endtask
    /* verilator lint_on INITIALDLY */

    task automatic master_complete(
        input  bit                     write,
        input  logic [DATA_WIDTH-1:0]  wdata,
        input  int unsigned max_wait_cycles,
        output logic [DATA_WIDTH-1:0] rdata,
        output logic                  resp,
        output int unsigned           wait_cycles,
        output bit                     completed,
        output bit                     reset_abort,
        output bit                     timed_out
    );
        rdata       = '0;
        resp        = 1'b0;
        wait_cycles = 0;
        completed   = 1'b0;
        reset_abort = 1'b0;
        timed_out   = 1'b0;

        // The first sampled edge is the address phase.  AHB completion is
        // sampled in the following data phase, so do not mistake the address
        // phase's normally-high HREADY for completion of this transfer.
        do begin
            @(master_sample_cb);
            if (!master_sample_cb.HRESETn) begin
                reset_abort = 1'b1;
                master_idle();
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

        // The serial BFM has no pipelined successor, so it holds the accepted
        // address/control and data signals through the complete data phase.
        // This is required when the data phase inserts HREADY-low waits.

        forever begin
            @(master_sample_cb);
            if (!master_sample_cb.HRESETn) begin
                reset_abort = 1'b1;
                master_idle();
                return;
            end
            if (master_sample_cb.HREADY) begin
                rdata     = master_sample_cb.HRDATA;
                resp      = master_sample_cb.HRESP;
                completed = 1'b1;
                @(master_drive_cb);
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
