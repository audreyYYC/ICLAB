/**************************************************************************/
// Copyright (c) 2025, OASIS Lab
// MODULE: PATTERN
// FILE NAME: PATTERN.v
// VERSRION: 1.0
// DATE: August 15, 2025
// AUTHOR: Yen-Yu Chen, NYCU ECE
// DESCRIPTION: ICLAB2025FALL / LAB3 / PATTERN
// MODIFICATION HISTORY:
// Date Description
//
/**************************************************************************/
`ifdef RTL
    `define CYCLE_TIME 11.0
`endif
`ifdef GATE
    `define CYCLE_TIME 11.0
`endif

module PATTERN (
// Output
    rst_n,
    clk,
    in_valid,
    pt_num,
    in_x,
    in_y,
// Input
    out_valid,
    out_x,
    out_y,
    drop_num
);

//---------------------------------------------------------------------
// PORT DECLARATION
//---------------------------------------------------------------------
output reg rst_n;
output reg clk;
output reg in_valid;
output reg [8:0] pt_num;
output reg [9:0] in_x;
output reg [9:0] in_y;

input out_valid;
input [9:0] out_x;
input [9:0] out_y;
input [6:0] drop_num;

//---------------------------------------------------------------------
// PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer total_latency;
integer current_cycle;
integer pattern_count;
integer current_pattern;
integer current_point;
integer file_handle;
integer i, k;
integer latency_count;

real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;

parameter MAX_PATTERNS = 100;
parameter MAX_POINTS = 500;

//---------------------------------------------------------------------
// REG & WIRE DECLARATION
//---------------------------------------------------------------------
// Input data storage
reg [8:0] pattern_pt_nums [0:MAX_PATTERNS-1];
reg [9:0] input_points_x [0:MAX_PATTERNS-1] [0:MAX_POINTS-1];
reg [9:0] input_points_y [0:MAX_PATTERNS-1] [0:MAX_POINTS-1];
reg reset_checking;

// Golden answer storage
reg [6:0] golden_drop_nums [0:MAX_PATTERNS-1] [0:MAX_POINTS-1];
reg [9:0] golden_drops_x [0:MAX_PATTERNS-1] [0:MAX_POINTS-1] [0:127];
reg [9:0] golden_drops_y [0:MAX_PATTERNS-1] [0:MAX_POINTS-1] [0:127];

// Convex hull calculation variables
reg [9:0] hull_x [0:127];
reg [9:0] hull_y [0:127];
reg [6:0] hull_next [0:127];
reg [6:0] hull_size;
reg [6:0] start_vertex;
reg signed [20:0] cross_product;
integer point_counter;

// Control variables
reg [6:0] expected_drops;
reg [6:0] received_drops;
reg [9:0] expected_x [0:127];
reg [9:0] expected_y [0:127];
reg [127:0] drop_received;

//---------------------------------------------------------------------
// SIMULATION
//---------------------------------------------------------------------
initial begin

    reset_task;

    file_handle = $fopen("../00_TESTBED/input.txt", "r");
    if (file_handle == 0) begin
        $display("Failed to open input.txt");
        $finish;
    end

    // 3 patterns
    $fscanf(file_handle, "%d", pattern_count);
    
    for (current_pattern = 0; current_pattern < pattern_count; current_pattern = current_pattern + 1) begin
        run_pattern;
    end

    $fclose(file_handle);
    $display ("--------------------------------------------------------------------------------------------------");
    $display ("                  Congratulations!               ");
    $display ("execution cycles = %7d", total_latency);
    $display ("clock period = %4.1fns", CYCLE);
    $display ("--------------------------------------------------------------------------------------------------");
    $finish;
end

// SPEC-5: Output values should be 0 when out_valid is 0
always @(*) begin
    if (!reset_checking) begin
        // out_valid is 0
        if ((out_valid === 1'b0) && ((drop_num !== 7'b0) || (out_x !== 10'b0) || (out_y !== 10'b0))) begin
            $display ("--------------------------------------------------------------------------------------------------");
            $display ("                    SPEC-5 FAIL                   ");
            $display ("--------------------------------------------------------------------------------------------------");
            $finish;
        end
        // drop_num is 0
        if ((drop_num === 7'b0) && ((out_x !== 10'b0) || (out_y !== 10'b0))) begin
            $display ("--------------------------------------------------------------------------------------------------");
            $display ("                    SPEC-5 FAIL                   ");
            $display ("--------------------------------------------------------------------------------------------------");
            $finish;
        end
    end
end

// SPEC-6: out_valid in_valid overlap
always @(*) begin
    if (in_valid && out_valid) begin
        $display ("--------------------------------------------------------------------------------------------------");
        $display ("                    SPEC-6 FAIL                   ");
        $display ("--------------------------------------------------------------------------------------------------");
        $finish;
    end
end

//---------------------------------------------------------------------
// TASKS
//---------------------------------------------------------------------
task reset_task; begin
    reset_checking = 1;
    rst_n = 1'b1;
    in_valid = 1'b0;
    pt_num = 9'b0;
    in_x = 10'b0;
    in_y = 10'b0;
    total_latency = 0;
    current_cycle = 0;
    point_counter = 0;
    hull_size = 0;
    start_vertex = 0;
    
    force clk = 0;
    
    #CYCLE;
    rst_n = 1'b0;
    #CYCLE;
    rst_n = 1'b1;
    #(100);
    if (out_valid !== 1'b0 || out_x !== 10'b0 || out_y !== 10'b0 || drop_num !== 7'b0) begin
        $display ("--------------------------------------------------------------------------------------------------");
        $display ("                    SPEC-4 FAIL                   ");
        $display ("--------------------------------------------------------------------------------------------------");
        $finish;
    end
    
    #CYCLE;
    release clk;
    reset_checking = 0;
end endtask


task run_pattern; begin
    integer point_count;
    reg [9:0] current_x, current_y;

    point_counter = 0;
    hull_size = 0;
    start_vertex = 0;
    for (i = 0; i < 128; i = i + 1) begin
        hull_x[i] = 0;
        hull_y[i] = 0;
        hull_next[i] = 0;
    end
    
    // read pt_num
    $fscanf(file_handle, "%d", point_count);
    
    repeat($urandom_range(1,4)) @(negedge clk);
    // 1st point + pt_num
    $fscanf(file_handle, "%d %d", current_x, current_y);
    in_valid = 1;
    pt_num = point_count;
    in_x = current_x;
    in_y = current_y;
    
    @(negedge clk);
    in_valid = 0;
    pt_num = 0;
    in_x = 0;
    in_y = 0;
    
    for (current_point = 1; current_point < point_count; current_point = current_point + 1) begin
        wait_out_finish(current_x, current_y);
        //@(negedge clk);
        
        // Read next point from file
        $fscanf(file_handle, "%d %d", current_x, current_y);
        // Send next point
        in_valid = 1;
        in_x = current_x;
        in_y = current_y;
        
        @(negedge clk);
        in_valid = 0;
        in_x = 0;
        in_y = 0;
    end
    wait_out_finish(current_x, current_y);
end endtask


    reg [9:0] expected_drop_count;
    reg [9:0] received_drop_count;
    reg [9:0] expected_xxx;
    reg [9:0] expected_yyy;
task wait_out_finish(input reg [9:0] point_x, point_y); begin
    integer cycle_count;
    reg [9:0] expected_drops_x [0:127];
    reg [9:0] expected_drops_y [0:127];
    reg [127:0] flag;
    integer drop_idx;
    integer found;
    
    cal_golden(point_x, point_y, expected_drop_count, expected_drops_x, expected_drops_y);
    latency_count = 1;
    while (!out_valid && latency_count < 1000) begin
        @(negedge clk);
        latency_count = latency_count + 1;
    end
    
    if (latency_count >= 1000) begin
        $display ("--------------------------------------------------------------------------------------------------");
        $display ("                    SPEC-7 FAIL                   ");
        $display ("--------------------------------------------------------------------------------------------------");
        $finish;
    end

    total_latency = total_latency + latency_count;
    received_drop_count = 0;
    cycle_count = 0;
    flag = 0;

    if(expected_drop_count == 0) begin
        @(negedge clk);
        return;
    end
    
    // SPEC-8: right answer
    while (out_valid) begin
        cycle_count = cycle_count + 1;
        
        if (drop_num !== expected_drop_count) begin
            $display ("--------------------------------------------------------------------------------------------------");
            $display ("                    SPEC-8 FAIL 1                    ");
            $display ("            drop_num !== expected_drop_count         ");
            $display ("--------------------------------------------------------------------------------------------------");
            $finish;
        end
        
        found = 0;
        for (drop_idx = 0; drop_idx < expected_drop_count; drop_idx = drop_idx + 1) begin
            expected_xxx = expected_drops_x[drop_idx];
            expected_yyy = expected_drops_y[drop_idx];
            if (!flag[drop_idx] && 
                out_x == expected_drops_x[drop_idx] && 
                out_y == expected_drops_y[drop_idx]) begin
                flag[drop_idx] = 1;
                found = 1;
                break;
            end
        end
        
        if (!found) begin
            $display ("--------------------------------------------------------------------------------------------------");
            $display ("                    SPEC-8 FAIL 2                    ");
            $display ("your (out_x, out_y) = (%d,%d) is not the expected drop", out_x, out_y);
            $display ("--------------------------------------------------------------------------------------------------");
            $finish;
        end
        
        received_drop_count = received_drop_count + 1;
        @(negedge clk);
    end
    
    // SPEC-9: continuous output
    if (expected_drop_count > 1 && cycle_count !== expected_drop_count) begin
        $display ("--------------------------------------------------------------------------------------------------");
        $display ("                    SPEC-9 FAIL                   ");
        $display ("--------------------------------------------------------------------------------------------------");
        $finish;
    end
    // SPEC-8: right answer
    if (received_drop_count !== expected_drop_count) begin
        $display ("--------------------------------------------------------------------------------------------------");
        $display ("SPEC-8 FAIL 3");
        $display ("--------------------------------------------------------------------------------------------------");
        $finish;
    end
end endtask

reg [9:0] new_x, new_y;
task cal_golden(
    input reg [9:0] point_x, point_y,
    output integer drop_count,
    output reg [9:0] drops_x [0:127],
    output reg [9:0] drops_y [0:127]
); begin
    //reg [9:0] new_x, new_y;
    new_x = point_x;
    new_y = point_y;
    
    drop_count = 0;
    
    if (point_counter < 3) begin
        if (point_counter == 0) begin
            hull_x[0] = new_x;
            hull_y[0] = new_y;
        end else if (point_counter == 1) begin
            hull_x[1] = new_x;
            hull_y[1] = new_y;
        end else begin // point_counter == 2
            hull_x[2] = new_x;
            hull_y[2] = new_y;
            
            // Initialize hull links
            hull_next[0] = 1;
            hull_next[1] = 2;
            hull_next[2] = 0;
            hull_size = 3;
            start_vertex = 0;
        end
        point_counter = point_counter + 1;
        return;
    end
    
    // Process point 4+
    process_point_against_hull(new_x, new_y, drop_count, drops_x, drops_y);
    point_counter = point_counter + 1;
end endtask
reg point_added;
task process_point_against_hull(
    input reg [9:0] new_x, new_y,
    output integer drop_count,
    output reg [9:0] drops_x [0:127],
    output reg [9:0] drops_y [0:127]
); begin
    integer cur_vertex, next_vertex, prev_vertex;
    reg signed [20:0] cp;
    reg circle_sign, prev_difside, cur_difside, prev_zero, cur_zero;
    
    integer traverse_count;
    
    drop_count = 0;
    point_added = 0;
    
    cp = signed_cross_product(
        hull_x[1] - hull_x[0], hull_y[1] - hull_y[0],
        hull_x[2] - hull_x[0], hull_y[2] - hull_y[0]
    );
    circle_sign = (cp < 0);
    
    // Start traversal
    cur_vertex = start_vertex;
    next_vertex = hull_next[cur_vertex];
    
    // First edge test
    cp = signed_cross_product(
        hull_x[next_vertex] - hull_x[cur_vertex],
        hull_y[next_vertex] - hull_y[cur_vertex],
        new_x - hull_x[cur_vertex],
        new_y - hull_y[cur_vertex]
    );
    
    cur_zero = (cp == 0);
    cur_difside = cur_zero ? 0 : ((cp < 0) != circle_sign);
    traverse_count = 0;
    
    // Traverse hull and find points to drop
    while (traverse_count < 128) begin
        prev_vertex = cur_vertex;
        cur_vertex = next_vertex;
        next_vertex = hull_next[next_vertex];
        
        prev_difside = cur_difside;
        prev_zero = cur_zero;
        
        cp = signed_cross_product(
            hull_x[next_vertex] - hull_x[cur_vertex],
            hull_y[next_vertex] - hull_y[cur_vertex],
            new_x - hull_x[cur_vertex],
            new_y - hull_y[cur_vertex]
        );
        
        cur_zero = (cp == 0);
        cur_difside = cur_zero ? 0 : ((cp < 0) != circle_sign);
        
        // Check if current vertex should be dropped
        if ((prev_difside || prev_zero) && (cur_difside || (cur_zero && !prev_zero))) begin
            drops_x[drop_count] = hull_x[cur_vertex];
            drops_y[drop_count] = hull_y[cur_vertex];
            drop_count = drop_count + 1;
        end
        
        // Update hull structure
        if (cur_difside) begin
            if (prev_zero)
                hull_next[prev_vertex] = hull_size;
            else
                hull_next[cur_vertex] = hull_size;
            point_added = 1;
        end else if (prev_difside) begin
            if (cur_zero)
                hull_next[hull_size] = next_vertex;
            else
                hull_next[hull_size] = cur_vertex;
            point_added = 1;
        end
        
        traverse_count = traverse_count + 1;
        if (cur_vertex == start_vertex) break;
    end

    
    if (point_added) begin
        // Add new point to hull
        hull_x[hull_size] = new_x;
        hull_y[hull_size] = new_y;
        start_vertex = hull_size;
        hull_size = hull_size + 1;
    end 
    else begin
        // Point is inside hull, add to drop list
        drops_x[drop_count] = new_x;
        drops_y[drop_count] = new_y;
        drop_count = drop_count + 1;
    end
end endtask

function signed [20:0] signed_cross_product(
    input signed [10:0] dx0,
    input signed [10:0] dy0,
    input signed [10:0] dx1,
    input signed [10:0] dy1
);
    signed_cross_product = dx0 * dy1 - dx1 * dy0;
endfunction

endmodule