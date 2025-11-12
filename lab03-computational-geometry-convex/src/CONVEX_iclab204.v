/**************************************************************************/
// Copyright (c) 2025, OASIS Lab
// MODULE: CONVEX
// FILE NAME: CONVEX.v
// VERSRION: 1.0
// DATE: August 15, 2025
// AUTHOR: Chao-En Kuo, NYCU IAIS
// DESCRIPTION: ICLAB2025FALL / LAB3 / CONVEX
// MODIFICATION HISTORY:
// Date Description
//
/**************************************************************************/
module CONVEX (
// Input
    rst_n,
    clk,
    in_valid,
    pt_num,
    in_x,
    in_y,
// Output
    out_valid,
    out_x,
    out_y,
    drop_num
);

//---------------------------------------------------------------------
// PORT DECLARATION
//---------------------------------------------------------------------
input rst_n;
input clk;
input in_valid;
input [8:0] pt_num;
input [9:0] in_x;
input [9:0] in_y;

output reg out_valid;
output reg [9:0] out_x;
output reg [9:0] out_y;
output reg [6:0] drop_num;

//---------------------------------------------------------------------
// PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
// State definitions
parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter COMPUTE = 2'd2;
parameter OUTPUT = 2'd3;

//---------------------------------------------------------------------
// REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg next_out_valid;
reg [9:0] next_out_x;
reg [9:0] next_out_y;
reg [6:0] next_drop_num;

// State machine
reg [1:0] state, next_state;

// Point counter and pattern info
reg [8:0] total_points, next_total_points;
reg [8:0] point_counter, next_point_counter;
reg [9:0] current_x, current_y, next_current_x, next_current_y;

// Hull storage
reg [9:0] hull_x [0:129];
reg [9:0] hull_y [0:129];
reg [9:0] next_hull_x [0:129];
reg [9:0] next_hull_y [0:129];
reg [7:0] hull_next [0:129];
reg [7:0] next_hull_next [0:129];
//reg [6:0] hull_size, next_hull_size;
reg [7:0] start_vertex, next_start_vertex;
reg circle_sign, next_circle_sign;
reg [7:0] temp;

reg point_connected, next_point_connected;
reg [7:0] cur_vertex, next_vertex, prev_vertex, next_cur_vertex, next_prev_vertex, next_next_vertex;
reg signed [20:0] cp;
reg prev_difside, cur_difside, prev_zero, cur_zero, next_prev_difside, next_cur_difside, next_prev_zero, next_cur_zero;
reg traversal_done;
reg [6:0] drop_count, next_drop_count;

// Drop buffer for output
reg [9:0] drop_buffer_x [0:127];
reg [9:0] drop_buffer_y [0:127];
reg [9:0] next_drop_buffer_x [0:127];
reg [9:0] next_drop_buffer_y [0:127];
reg [6:0] drops_to_output, next_drops_to_output;
reg [7:0] output_counter, next_output_counter;
reg [7:0] nstart, next_nstart;

// Cross product inputs
reg signed [10:0] dx0, dy0, dx1, dy1;
wire signed [20:0] cp_result;


reg [7:0] empty [0:129];
reg [7:0] next_empty [0:129];
reg [7:0] pointer, next_pointer;
//---------------------------------------------------------------------
// CROSS PRODUCT MODULE
//---------------------------------------------------------------------
assign cp_result = dx0 * dy1 - dx1 * dy0;

//---------------------------------------------------------------------
// STATE MACHINE
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    case (state)
        IDLE: begin
            if (in_valid)
                next_state = INPUT;
            else
                next_state = IDLE;
        end
        
        INPUT: begin
            if (point_counter <= 3) 
                next_state = IDLE;
            else 
                next_state = COMPUTE;
        end

        COMPUTE: begin
            if (traversal_done) 
                next_state = OUTPUT;
            else
                next_state = COMPUTE;
        end
        
        OUTPUT: begin
            if (drops_to_output == 0) begin
                //if (output_counter >= 1)
                    next_state = IDLE;
                //else
                //    next_state = OUTPUT;
            end
            else begin
                if (output_counter >= drops_to_output)
                    next_state = IDLE;
                else
                    next_state = OUTPUT;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

//---------------------------------------------------------------------
// MAIN LOGIC
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out_x <= 0;
        out_y <= 0;
        drop_num <= 0;
        total_points <= 0;
        point_counter <= 0;
        current_x <= 0;
        current_y <= 0;
        //hull_size <= 0;
        start_vertex <= 0;
        drops_to_output <= 0;
        output_counter <= 0;
        circle_sign <= 0;
        for (integer i = 0; i < 130; i = i + 1) begin
            hull_x[i] <= 0;
            hull_y[i] <= 0;
            hull_next[i] <= 0;
            drop_buffer_x[i] <= 0;
            drop_buffer_y[i] <= 0;
            empty[i] <= 0;
        end
        cur_vertex <= 0;
        next_vertex <= 0;
        prev_vertex <= 0;
        cur_difside <= 0;
        prev_difside <= 0;
        cur_zero <= 0;
        prev_zero <= 0;
        point_connected <= 0;
        drop_count <= 0;
        pointer <= 0;
        nstart <= 0;

    end
    else begin
        out_valid <= next_out_valid;
        out_x <= next_out_x;
        out_y <= next_out_y;
        drop_num <= next_drop_num;
        total_points <= next_total_points;
        point_counter <= next_point_counter;
        current_x <= next_current_x;
        current_y <= next_current_y;
        //hull_size <= next_hull_size;
        start_vertex <= next_start_vertex;
        drops_to_output <= next_drops_to_output;
        output_counter <= next_output_counter;
        circle_sign <= next_circle_sign;
        for (integer i = 0; i < 130; i = i + 1) begin
            hull_x[i] <= next_hull_x[i];
            hull_y[i] <= next_hull_y[i];
            hull_next[i] <= next_hull_next[i];
            drop_buffer_x[i] <= next_drop_buffer_x[i];
            drop_buffer_y[i] <= next_drop_buffer_y[i];
            empty[i] <= next_empty[i];
        end
        cur_vertex <= next_cur_vertex;
        next_vertex <= next_next_vertex;
        prev_vertex <= next_prev_vertex;
        cur_difside <= next_cur_difside;
        prev_difside <= next_prev_difside;
        cur_zero <= next_cur_zero;
        prev_zero <= next_prev_zero;
        point_connected <= next_point_connected;
        drop_count <= next_drop_count;
        pointer <= next_pointer;
        nstart <= next_nstart;
    end
end

//reg flag;
always @(*) begin
    next_out_valid = 0;
    next_out_x = 0;
    next_out_y = 0;
    next_drop_num = 0;
    next_point_counter = point_counter;
    next_total_points = total_points;
    next_current_x = current_x;
    next_current_y = current_y;
    next_drops_to_output = drops_to_output;
    next_output_counter = output_counter;
    next_circle_sign = circle_sign;
    next_drop_count = drop_count;
    dx0 = 0;
    dx1 = 0;
    dy0 = 0;
    dy1 = 0;
    traversal_done = 0;
    next_point_connected = point_connected;
    next_start_vertex = start_vertex;
    next_prev_zero = 0;
    next_prev_difside = 0;
    next_cur_zero = 0;
    next_cur_difside = 0;
    next_cur_vertex = cur_vertex;
    next_prev_vertex = prev_vertex;
    next_next_vertex = next_vertex;
    next_nstart = nstart;

    //next_hull_size = hull_size;
    next_pointer = pointer;
    for (integer i = 0; i < 130; i = i + 1) begin
        next_hull_x[i] = hull_x[i];
        next_hull_y[i] = hull_y[i];
        next_hull_next[i] = hull_next[i];
        next_drop_buffer_x[i] = drop_buffer_x[i];
        next_drop_buffer_y[i] = drop_buffer_y[i];
        next_empty[i] = empty[i];
    end

    case (state)
        IDLE: begin
            if (in_valid) begin
                next_current_x = in_x;
                next_current_y = in_y;
                
                if (point_counter == 0) begin
                    // First point of pattern - store pt_num
                    next_total_points = pt_num;
                    next_point_counter = 1;
                    //next_hull_size = 0;
                    next_start_vertex = 0;
                    next_pointer = 0;
                    for (integer i = 0; i < 130; i = i + 1) begin
                        next_hull_x[i] = 0;
                        next_hull_y[i] = 0;
                        next_hull_next[i] = 0;
                        next_empty[i] = i;
                    end
                end
                else begin
                    next_point_counter = point_counter + 1;
                end
            end
        end
        
        INPUT: begin //First three points
            if (point_counter <= 3) begin
                next_hull_x[point_counter-1] = current_x;
                next_hull_y[point_counter-1] = current_y;

                next_out_valid = 1;
                
                if (point_counter == 3) begin
                    next_hull_next[0] = 1;
                    next_hull_next[1] = 2;
                    next_hull_next[2] = 0;
                    //next_hull_size = 3;
                    next_pointer = 3;

                    // Determine hull orientation
                    dx0 = hull_x[1] - hull_x[0];
                    dy0 = hull_y[1] - hull_y[0];
                    dx1 = next_hull_x[2] - hull_x[0];
                    dy1 = next_hull_y[2] - hull_y[0];
                    next_circle_sign = (cp_result < 0);

                    next_start_vertex = 0;
                    next_prev_vertex = 0;
                    next_cur_vertex = 0;
                    next_next_vertex = 0;
                end
            end
            else begin
                // Start traversal
                temp = hull_next[start_vertex];

                dx0 = hull_x[temp] - hull_x[start_vertex];
                dy0 = hull_y[temp] - hull_y[start_vertex];
                dx1 = current_x - hull_x[start_vertex];
                dy1 = current_y - hull_y[start_vertex];
                cp = cp_result;
                
                next_cur_zero = (cp == 0);
                next_cur_difside = next_cur_zero ? 0 : (cp[20] != circle_sign);

                next_prev_difside = 0;
                next_prev_zero = 0;
                next_drop_count = 0;
                next_point_connected = 0;

                next_prev_vertex = start_vertex;
                next_cur_vertex = hull_next[start_vertex];
                next_next_vertex = hull_next[temp];
                next_prev_difside = next_cur_difside;
                next_prev_zero = (cp == 0);

                next_hull_x[empty[pointer]] = current_x;
                next_hull_y[empty[pointer]] = current_y;
                next_nstart = empty[pointer];

            end
        end

        COMPUTE: begin
            dx0 = hull_x[next_vertex] - hull_x[cur_vertex];
            dy0 = hull_y[next_vertex] - hull_y[cur_vertex];
            dx1 = current_x - hull_x[cur_vertex];
            dy1 = current_y - hull_y[cur_vertex];
            cp = cp_result;
            
            next_cur_zero = (cp == 0);
            next_cur_difside = next_cur_zero ? 0 : (cp[20] != circle_sign);
            
            // Check for drop points
            if ((prev_difside || prev_zero) && (next_cur_difside || (next_cur_zero && !prev_zero))) begin
                next_drop_buffer_x[drop_count] = hull_x[cur_vertex];
                next_drop_buffer_y[drop_count] = hull_y[cur_vertex];
                next_drop_count = drop_count + 1;
                next_empty[pointer] = cur_vertex;
                next_pointer = pointer - 1;
            end

            // Hull connection
            if (next_cur_difside) begin
                if (prev_zero) begin
                    next_hull_next[prev_vertex] = nstart;
                end else begin
                    next_hull_next[cur_vertex] = nstart;
                end
                next_point_connected = 1;
            end
            else if (prev_difside) begin
                if (next_cur_zero) begin
                    next_hull_next[nstart] = next_vertex;
                end else begin
                    next_hull_next[nstart] = cur_vertex;
                end
                next_point_connected = 1;
            end
            
            
            if (cur_vertex == start_vertex) begin //complete
                traversal_done = 1;

                if (next_point_connected) begin // Point was added to hull
                    next_pointer = next_pointer + 1;
                    next_start_vertex = nstart;
                end 
                else begin // Point is inside : drop it
                    next_drop_buffer_x[0] = current_x;
                    next_drop_buffer_y[0] = current_y;
                    next_drop_count = 1;
                end
                
                next_drops_to_output = next_drop_count;
            end
            else begin
                next_prev_vertex = cur_vertex;
                next_cur_vertex = next_vertex;
                next_next_vertex = hull_next[next_vertex];
                next_prev_difside = next_cur_difside;
                next_prev_zero = next_cur_zero;
            end

            if (point_counter >= total_points) begin // Pattern complete, reset for next pattern
                next_point_counter = 0;

            end
        end
        
        OUTPUT: begin
            next_out_valid = 1;
            next_drop_num = drops_to_output;
            
            if (drops_to_output == 0) begin // no drops: 1/0/0/0
                next_output_counter = 0;
            end
            else begin // Normal multi-drop output
                if (output_counter < drops_to_output) begin
                    next_out_x = drop_buffer_x[output_counter];
                    next_out_y = drop_buffer_y[output_counter];
                    next_output_counter = output_counter + 1;
                end
                else begin
                    next_output_counter = 0;
                    next_out_valid = 0;
                    next_drop_num = 0;
                end
            end
        end
    endcase
end

endmodule