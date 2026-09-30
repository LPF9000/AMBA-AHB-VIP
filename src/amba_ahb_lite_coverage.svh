`uvm_analysis_imp_decl(_coverage_cycle)
`uvm_analysis_imp_decl(_coverage_reset)
`uvm_analysis_imp_decl(_coverage_abort)

class amba_ahb_lite_coverage extends uvm_subscriber #(amba_ahb_lite_observed_item);
    `uvm_component_utils(amba_ahb_lite_coverage)
    uvm_analysis_imp_coverage_cycle #(amba_ahb_lite_cycle_item,
        amba_ahb_lite_coverage) cycle_export;
    uvm_analysis_imp_coverage_reset #(amba_ahb_lite_reset_event,
        amba_ahb_lite_coverage) reset_export;
    uvm_analysis_imp_coverage_abort #(amba_ahb_lite_observed_item,
        amba_ahb_lite_coverage) aborted_export;
    protected int unsigned size_counts[3];
    protected int unsigned burst_counts[8];
    protected int unsigned direction_counts[2];
    protected int unsigned response_counts[2];
    protected int unsigned lane_counts[4];
    protected int unsigned size_direction_counts[3][2];
    protected int unsigned wait_counts[3];
    protected int unsigned busy_count;
    protected int unsigned idle_count;
    protected int unsigned reset_count;
    protected int unsigned abort_count;
    protected string output_path;
    ahb_hsize_e size_sample;
    ahb_hburst_e burst_sample;
    ahb_hresp_e resp_sample;
    bit write_sample;
    int unsigned wait_sample;

    covergroup transfer_cg;
        option.per_instance = 1;
        cp_size: coverpoint size_sample {
            bins byte_size = {AHB_BYTE};
            bins halfword = {AHB_HWORD};
            bins word_size = {AHB_WORD};
            illegal_bins unsupported = default;
        }
        cp_burst: coverpoint burst_sample;
        cp_resp: coverpoint resp_sample;
        cp_write: coverpoint write_sample;
        cp_wait: coverpoint wait_sample {
            bins no_wait = {0};
            bins waited = {[1:16]};
            bins long_wait = {[17:$]};
        }
        size_x_direction: cross cp_size, cp_write;
        burst_x_response: cross cp_burst, cp_resp;
    endgroup

    function new(string name = "amba_ahb_lite_coverage", uvm_component parent = null);
        super.new(name, parent);
        cycle_export = new("cycle_export", this);
        reset_export = new("reset_export", this);
        aborted_export = new("aborted_export", this);
        transfer_cg = new();
    endfunction

    function void write(amba_ahb_lite_observed_item item);
        size_sample = item.size;
        burst_sample = item.burst;
        resp_sample = item.resp;
        write_sample = item.write;
        wait_sample = item.wait_cycles;
        transfer_cg.sample();
        if (item.size inside {AHB_BYTE, AHB_HWORD, AHB_WORD}) begin
            size_counts[int'(item.size)]++;
            size_direction_counts[int'(item.size)][int'(item.write)]++;
        end
        burst_counts[int'(item.burst)]++;
        direction_counts[int'(item.write)]++;
        response_counts[int'(item.resp)]++;
        lane_counts[int'(item.addr[1:0])]++;
        wait_counts[item.wait_cycles == 0 ? 0 : item.wait_cycles <= 16 ? 1 : 2]++;
    endfunction

    function void write_coverage_cycle(amba_ahb_lite_cycle_item item);
        if (item.reset_n && item.ready) begin
            if (item.trans == AHB_BUSY)
                busy_count++;
            if (item.trans == AHB_IDLE)
                idle_count++;
        end
    endfunction

    function void write_coverage_reset(amba_ahb_lite_reset_event item);
        reset_count++;
    endfunction

    function void write_coverage_abort(amba_ahb_lite_observed_item item);
        abort_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        int file_handle;
        super.report_phase(phase);
        if (!$value$plusargs("AHB_COVERAGE_FILE=%s", output_path))
            return;
        file_handle = $fopen(output_path, "w");
        if (file_handle == 0) begin
            `uvm_error("AHB_COVERAGE", "Cannot open functional coverage counter report")
            return;
        end
        $fdisplay(file_handle, "{");
        $fdisplay(file_handle, "    \"sizes\": [%0d, %0d, %0d],", size_counts[0], size_counts[1], size_counts[2]);
        $fdisplay(file_handle, "    \"bursts\": [%0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d],",
            burst_counts[0], burst_counts[1], burst_counts[2], burst_counts[3],
            burst_counts[4], burst_counts[5], burst_counts[6], burst_counts[7]);
        $fdisplay(file_handle, "    \"directions\": [%0d, %0d],", direction_counts[0], direction_counts[1]);
        $fdisplay(file_handle, "    \"responses\": [%0d, %0d],", response_counts[0], response_counts[1]);
        $fdisplay(file_handle, "    \"lanes\": [%0d, %0d, %0d, %0d],", lane_counts[0], lane_counts[1], lane_counts[2], lane_counts[3]);
        $fdisplay(file_handle, "    \"size_direction\": [[%0d,%0d],[%0d,%0d],[%0d,%0d]],",
            size_direction_counts[0][0], size_direction_counts[0][1],
            size_direction_counts[1][0], size_direction_counts[1][1],
            size_direction_counts[2][0], size_direction_counts[2][1]);
        $fdisplay(file_handle, "    \"waits\": [%0d, %0d, %0d],", wait_counts[0], wait_counts[1], wait_counts[2]);
        $fdisplay(file_handle, "    \"busy\": %0d, \"idle\": %0d, \"resets\": %0d, \"aborts\": %0d",
            busy_count, idle_count, reset_count, abort_count);
        $fdisplay(file_handle, "}");
        $fclose(file_handle);
    endfunction
endclass
