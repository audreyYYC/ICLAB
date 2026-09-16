module MVDM(
    // input signals
    input clk,
    input rst_n,
    input in_valid, 
    input in_valid2,
    input [8:0] in_data,
    // output signals
    output reg out_valid,
    output reg out_sad
);

//=======================================================
// Parameters & Local Parameters
//=======================================================
localparam IDLE       = 4'd0;
localparam LOAD_L0    = 4'd1;
localparam LOAD_L1    = 4'd2;
localparam WAIT_MV    = 4'd3;
localparam READ_MV    = 4'd4;
localparam P2_MV      = 4'd8;
localparam CALC_BI    = 4'd5;
localparam CALC_SATD  = 4'd6;
localparam OUTPUT     = 4'd7;

//=======================================================
// Reg/Wire Declaration
//=======================================================
// FSM
reg [3:0] state, next_state;

// SRAM interface - SEPARATE ADDRESSES
reg [13:0] mem_addr_l0, mem_addr_l1;
reg [13:0] mem_addr_l0_next, mem_addr_l1_next;
reg [7:0] mem_wdata;
reg mem_we_l0, mem_we_l1;
wire [7:0] mem_rdata_l0, mem_rdata_l1;

// Loading counter
reg [14:0] load_cnt;
reg [14:0] load_cnt_next;

// MV storage - Point 1
reg [7:0] mv_x_l0_p1, mv_y_l0_p1;
reg [7:0] mv_x_l1_p1, mv_y_l1_p1;
reg frac_x_l0_p1, frac_y_l0_p1;
reg frac_x_l1_p1, frac_y_l1_p1;

// MV storage - Point 2
reg [7:0] mv_x_l0_p2, mv_y_l0_p2;
reg [7:0] mv_x_l1_p2, mv_y_l1_p2;
reg frac_x_l0_p2, frac_y_l0_p2;
reg frac_x_l1_p2, frac_y_l1_p2;

reg [2:0] mv_cnt;

// BI calculation - DUPLICATED for L0 and L1
reg signed [15:0] BI_buffer_L0 [0:14][0:9];
reg signed [15:0] BI_buffer_L1 [0:14][0:9];

// SEPARATE counters for L0 and L1
reg [6:0] bi_total_cnt_l0;   // L0 counter: 0~99
reg [6:0] bi_total_cnt_l1;   // L1 counter: 0~99
reg bi_done_l0;              // L0 finished flag
reg bi_done_l1;              // L1 finished flag

// Shared position counters (both use same iteration pattern)
reg [3:0] bi_row_l0, bi_col_l0;
reg [3:0] bi_row_l1, bi_col_l1;
reg [4:0] pixel_cnt_l0, pixel_cnt_l1;

reg [1:0] interp_mode_l0, interp_mode_l1;

// Base position tracking - SEPARATE
reg signed [8:0] base_y_l0, base_x_l0;
reg signed [8:0] base_y_l1, base_x_l1;

// FIR intermediate
reg signed [14:0] fir_result_l0, fir_result_l1;
reg signed [7:0] fir_clipped_h_v_l0, fir_clipped_h_v_l1;
reg signed [7:0] fir_clipped_2d_l0, fir_clipped_2d_l1;

// 2D interpolation
reg h_phase_done_l0, h_phase_done_l1;
reg flag_l0, flag_l1;

// Pattern and output control
reg [5:0] pattern_cnt;
reg [4:0] output_cnt;

// Current read address calculation - SEPARATE
reg signed [8:0] read_y_l0, read_x_l0;
reg signed [8:0] read_y_l1, read_x_l1;



// SATD
// Pipeline registers
reg signed [8:0] stage1_diff [0:15];      // Stage 1: Differences (9-bit signed)
reg signed [11:0] stage2_h [0:15];        // Stage 2: After H transform (12-bit)
reg signed [13:0] stage3_ht [0:15];       // Stage 3: After HT transform (14-bit)
reg [15:0] stage4_partial [0:3];          // Stage 4: Partial sums (4 groups, 16-bit)
reg [17:0] stage5_satd;                   // Stage 5: Final SATD for one sub-block

// Pipeline valid signals
reg stage1_valid, stage2_valid, stage3_valid, stage4_valid, stage5_valid;

// SATD state
reg [23:0] current_point_satd;            // Accumulating SATD for current search point
reg [1:0] subblk_cnt;                     // Which sub-block: 0-3
reg [3:0] search_point;                   // Current search point: 0-8
reg [5:0] satd_cycle_cnt;                 // Cycle counter
reg [23:0] min_satd;
reg [3:0] min_point;

// Search pattern offset (Mirror MVD matching)
reg signed [1:0] dx_l0, dy_l0;            // L0 offsets
reg signed [1:0] dx_l1, dy_l1;            // L1 offsets (mirrored)

// output TEMP
reg point_1_done;
reg [27:0] out_point_1;
reg next_out_sad, next_out_valid;

//=======================================================
// Helper Functions
//=======================================================
function [7:0] clip_coord;
    input signed [8:0] coord;
    begin
        if (coord < 0) 
            clip_coord = 8'd0;
        else if (coord > 127)
            clip_coord = 8'd127;
        else
            clip_coord = coord[7:0];
    end
endfunction

function [7:0] clip_pixel;
    input signed [15:0] val;
    begin
        if (val < 0)
            clip_pixel = 8'd0;
        else if (val > 255)
            clip_pixel = 8'd255;
        else
            clip_pixel = val[7:0];
    end
endfunction

function [13:0] calc_addr;
    input [7:0] y, x;
    begin
        calc_addr = {y[6:0], x[6:0]};
    end
endfunction

//=======================================================
// FSM - State Transition
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (in_valid) 
                next_state = LOAD_L0;
        end
        
        LOAD_L0: begin
            if (load_cnt == 16383) 
                next_state = LOAD_L1;
        end
        
        LOAD_L1: begin
            if (load_cnt == 16383) 
                next_state = WAIT_MV;
        end
        
        WAIT_MV: begin
            if (in_valid2) 
                next_state = READ_MV;
        end
        
        READ_MV: begin
            if (mv_cnt == 7) 
                next_state = CALC_BI;
        end
        
        CALC_BI: begin
            // Wait for BOTH L0 and L1 to finish
            if (bi_done_l0 && bi_done_l1) 
                next_state = CALC_SATD;
        end
        
        CALC_SATD: begin
            if (satd_cycle_cnt == 41) begin
                next_state = point_1_done ? OUTPUT : P2_MV;
            end
        end
        
        OUTPUT: begin
            if (output_cnt == 27) begin
                if (pattern_cnt == 63) 
                    next_state = IDLE;
                else 
                    next_state = WAIT_MV;
            end
        end

        P2_MV: begin
            next_state = CALC_BI;
        end
    endcase
end

//=======================================================
// SEPARATE MEMORY ADDRESS DRIVERS
//=======================================================
always @(*) begin
    case (state)
        LOAD_L0: begin
            mem_addr_l0_next = load_cnt_next[13:0];
            mem_addr_l1_next = 14'd0;
        end
        
        LOAD_L1: begin
            mem_addr_l0_next = 14'd0;
            mem_addr_l1_next = load_cnt_next[13:0];
        end
        
        CALC_BI: begin
            mem_addr_l0_next = calc_addr(read_y_l0, read_x_l0);
            mem_addr_l1_next = calc_addr(read_y_l1, read_x_l1);
        end
        
        default: begin
            mem_addr_l0_next = 14'd0;
            mem_addr_l1_next = 14'd0;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_addr_l0 <= 14'd0;
        mem_addr_l1 <= 14'd0;
    end
    else begin
        mem_addr_l0 <= mem_addr_l0_next;
        mem_addr_l1 <= mem_addr_l1_next;
    end
end

//=======================================================
// Memory Write Control
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_we_l0 <= 1'b0;
        mem_we_l1 <= 1'b0;
        mem_wdata <= 8'd0;
    end else begin
        case (next_state)
            IDLE: begin
                mem_we_l0 <= 0;
                mem_we_l1 <= 0;
                mem_wdata <= 8'd0;
            end
            
            LOAD_L0: begin
                mem_we_l0 <= 1;
                mem_we_l1 <= 0;
                mem_wdata <= in_data[8:1];
            end
            
            LOAD_L1: begin
                mem_we_l0 <= 0;
                mem_we_l1 <= 1;
                mem_wdata <= in_data[8:1];
            end
            
            default: begin
                mem_we_l0 <= 1'b0;
                mem_we_l1 <= 1'b0;
                mem_wdata <= 8'd0;
            end
        endcase
    end
end

//=======================================================
// Loading Counter
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        load_cnt <= 15'd0;
    end else begin
        load_cnt <= load_cnt_next;
    end
end

always @(*) begin
    load_cnt_next = load_cnt;
    if (state == LOAD_L0 && next_state == LOAD_L1) begin
        load_cnt_next = 0;
    end else if (state == LOAD_L1 && next_state == WAIT_MV) begin
        load_cnt_next = 0;
    end else if ((state == LOAD_L0 || state == LOAD_L1)) begin
        load_cnt_next = load_cnt + 1;
    end
end

//=======================================================
// Reading MV Data
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mv_cnt <= 3'd0;
        {mv_x_l0_p1, mv_y_l0_p1, frac_x_l0_p1, frac_y_l0_p1} <= 0;
        {mv_x_l1_p1, mv_y_l1_p1, frac_x_l1_p1, frac_y_l1_p1} <= 0;
        {mv_x_l0_p2, mv_y_l0_p2, frac_x_l0_p2, frac_y_l0_p2} <= 0;
        {mv_x_l1_p2, mv_y_l1_p2, frac_x_l1_p2, frac_y_l1_p2} <= 0;
    end
    else if (in_valid2) begin
        mv_cnt <= mv_cnt + 1'd1;
        
        case (mv_cnt)
            3'd0: begin
                mv_x_l0_p1 <= in_data[8:1];
                frac_x_l0_p1 <= in_data[0];
            end
            3'd1: begin
                mv_y_l0_p1 <= in_data[8:1];
                frac_y_l0_p1 <= in_data[0];
            end
            3'd2: begin
                mv_x_l1_p1 <= in_data[8:1];
                frac_x_l1_p1 <= in_data[0];
            end
            3'd3: begin
                mv_y_l1_p1 <= in_data[8:1];
                frac_y_l1_p1 <= in_data[0];
            end
            3'd4: begin
                mv_x_l0_p2 <= in_data[8:1];
                frac_x_l0_p2 <= in_data[0];
            end
            3'd5: begin
                mv_y_l0_p2 <= in_data[8:1];
                frac_y_l0_p2 <= in_data[0];
            end
            3'd6: begin
                mv_x_l1_p2 <= in_data[8:1];
                frac_x_l1_p2 <= in_data[0];
            end
            3'd7: begin
                mv_y_l1_p2 <= in_data[8:1];
                frac_y_l1_p2 <= in_data[0];
            end
        endcase
    end
    else if (state == WAIT_MV) begin
        mv_cnt <= 3'd0;
    end
end

//=======================================================
// BI Calculation Setup
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        interp_mode_l0 <= 2'b00;
        base_x_l0 <= 9'd0;
        base_y_l0 <= 9'd0;
        interp_mode_l1 <= 2'b00;
        base_x_l1 <= 9'd0;
        base_y_l1 <= 9'd0;
    end
    else if (state == READ_MV && mv_cnt == 7) begin
        // Setup for L0 point1 calculation
        interp_mode_l0 <= {frac_y_l0_p1, frac_x_l0_p1};
        if (frac_x_l0_p1) 
            base_x_l0 <= mv_x_l0_p1 - 2;
        else
            base_x_l0 <= mv_x_l0_p1;
        
        if(frac_y_l0_p1) 
            base_y_l0 <= mv_y_l0_p1 - 2;
        else
            base_y_l0 <= mv_y_l0_p1;
        
        // Setup for L1 point1 calculation
        interp_mode_l1 <= {frac_y_l1_p1, frac_x_l1_p1};

        if (frac_x_l1_p1)
            base_x_l1 <= mv_x_l1_p1 - 2;
        else 
            base_x_l1 <= mv_x_l1_p1;

        if (frac_y_l1_p1) 
            base_y_l1 <= mv_y_l1_p1 - 2;
        else 
            base_y_l1 <= mv_y_l1_p1;
    end

    else if(state == P2_MV) begin
        // Setup for L0 point1 calculation
        interp_mode_l0 <= {frac_y_l0_p2, frac_x_l0_p2};
        if (frac_x_l0_p2) 
            base_x_l0 <= mv_x_l0_p2 - 2;
        else
            base_x_l0 <= mv_x_l0_p2;
        
        if(frac_y_l0_p2) 
            base_y_l0 <= mv_y_l0_p2 - 2;
        else
            base_y_l0 <= mv_y_l0_p2;
        
        // Setup for L1 point1 calculation
        interp_mode_l1 <= {frac_y_l1_p2, frac_x_l1_p2};

        if (frac_x_l1_p2)
            base_x_l1 <= mv_x_l1_p2 - 2;
        else 
            base_x_l1 <= mv_x_l1_p2;

        if (frac_y_l1_p2) 
            base_y_l1 <= mv_y_l1_p2 - 2;
        else 
            base_y_l1 <= mv_y_l1_p2;
    end

end

//=======================================================
// 6-tap FIR Filter Calculation
//=======================================================
reg [7:0] p_array_l0 [0:5];
reg [7:0] p_array_l1 [0:5];
reg signed [14:0] v_array_l0 [0:5];
reg signed [14:0] v_array_l1 [0:5];
reg signed [20:0] hv_result_l0, hv_result_l1;


// L0 FIR
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 6; i = i + 1) begin
            p_array_l0[i] <= 8'd0;
            v_array_l0[i] <= 15'd0;
        end
    end
    else begin
        // Always shift p_array and load new pixel from SRAM
        p_array_l0[0] <= p_array_l0[1];
        p_array_l0[1] <= p_array_l0[2];
        p_array_l0[2] <= p_array_l0[3];
        p_array_l0[3] <= p_array_l0[4];
        p_array_l0[4] <= p_array_l0[5];
        p_array_l0[5] <= mem_rdata_l0;
    
        v_array_l0[0] <= BI_buffer_L0[10][0];
        v_array_l0[1] <= BI_buffer_L0[11][0];
        v_array_l0[2] <= BI_buffer_L0[12][0];
        v_array_l0[3] <= BI_buffer_L0[13][0];
        v_array_l0[4] <= BI_buffer_L0[14][0];
        v_array_l0[5] <= fir_result_l0;
    end
end

always @(*) begin
    fir_result_l0 = (p_array_l0[0] + p_array_l0[5]) 
                  - (p_array_l0[1] + p_array_l0[4]) * 5 
                  + (p_array_l0[2] + p_array_l0[3]) * 20;

    hv_result_l0 = (v_array_l0[0] + v_array_l0[5]) 
                 - (v_array_l0[1] + v_array_l0[4]) * 5 
                 + (v_array_l0[2] + v_array_l0[3]) * 20;
end

always @(*) begin
    fir_clipped_h_v_l0 = clip_pixel((fir_result_l0 + 16) >>> 5);
    fir_clipped_2d_l0 = clip_pixel((hv_result_l0 + 512) >>> 10);
end

// L1 FIR
always @(posedge clk or negedge rst_n) begin
    if( !rst_n) begin
        for (integer i = 0; i < 6; i = i + 1) begin
            p_array_l1[i] <= 8'd0;
            v_array_l1[i] <= 15'd0;
        end
    end
    else begin
        // Always shift p_array and load new pixel from SRAM
        p_array_l1[0] <= p_array_l1[1];
        p_array_l1[1] <= p_array_l1[2];
        p_array_l1[2] <= p_array_l1[3];
        p_array_l1[3] <= p_array_l1[4];
        p_array_l1[4] <= p_array_l1[5];
        p_array_l1[5] <= mem_rdata_l1;
    
        v_array_l1[0] <= BI_buffer_L1[10][0];
        v_array_l1[1] <= BI_buffer_L1[11][0];
        v_array_l1[2] <= BI_buffer_L1[12][0];
        v_array_l1[3] <= BI_buffer_L1[13][0];
        v_array_l1[4] <= BI_buffer_L1[14][0];
        v_array_l1[5] <= fir_result_l1;
    end
end
always @(*) begin
    fir_result_l1 = (p_array_l1[0] + p_array_l1[5]) 
                  - (p_array_l1[1] + p_array_l1[4]) * 5 
                  + (p_array_l1[2] + p_array_l1[3]) * 20;

    hv_result_l1 = (v_array_l1[0] + v_array_l1[5]) 
                 - (v_array_l1[1] + v_array_l1[4]) * 5 
                 + (v_array_l1[2] + v_array_l1[3]) * 20;
end

always @(*) begin
    fir_clipped_h_v_l1 = clip_pixel((fir_result_l1 + 16) >>> 5);
    fir_clipped_2d_l1 = clip_pixel((hv_result_l1 + 512) >>> 10);
end

//=======================================================
// Read Address Generation
//=======================================================
always @(*) begin
    case (interp_mode_l0)
        2'b00: begin
            read_y_l0 = clip_coord(base_y_l0 + bi_row_l0);
            read_x_l0 = clip_coord(base_x_l0 + bi_col_l0);
        end
        2'b01: begin
            read_y_l0 = clip_coord(base_y_l0 + bi_row_l0);
            read_x_l0 = clip_coord(base_x_l0 + pixel_cnt_l0);
        end
        2'b10: begin
            read_y_l0 = clip_coord(base_y_l0 + pixel_cnt_l0);
            read_x_l0 = clip_coord(base_x_l0 + bi_col_l0);
        end
        2'b11: begin
            read_y_l0 = clip_coord(base_y_l0 + bi_row_l0);
            read_x_l0 = clip_coord(base_x_l0 + pixel_cnt_l0);
        end
        default: begin
            read_y_l0 = 8'd0;
            read_x_l0 = 8'd0;
        end
    endcase

    case (interp_mode_l1)
        2'b00: begin
            read_y_l1 = clip_coord(base_y_l1 + bi_row_l1);
            read_x_l1 = clip_coord(base_x_l1 + bi_col_l1);
        end
        2'b01: begin
            read_y_l1 = clip_coord(base_y_l1 + bi_row_l1);
            read_x_l1 = clip_coord(base_x_l1 + pixel_cnt_l1);
        end
        2'b10: begin
            read_y_l1 = clip_coord(base_y_l1 + pixel_cnt_l1);
            read_x_l1 = clip_coord(base_x_l1 + bi_col_l1);
        end
        2'b11: begin
            read_y_l1 = clip_coord(base_y_l1 + bi_row_l1);
            read_x_l1 = clip_coord(base_x_l1 + pixel_cnt_l1);
        end
        default: begin
            read_y_l1 = 8'd0;
            read_x_l1 = 8'd0;
        end
    endcase
end

//=======================================================
// BI Calculation - L0
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bi_total_cnt_l0 <= 7'd0;
        bi_row_l0 <= 4'd0;
        bi_col_l0 <= 4'd0;
        pixel_cnt_l0 <= 4'd0;
        h_phase_done_l0 <= 1'b0;
        bi_done_l0 <= 1'b0;
        flag_l0 <= 0;
        
        for (integer i = 0; i < 10; i = i + 1) begin
            for (integer j = 0; j < 15; j = j + 1) begin
                BI_buffer_L0[i][j] <= 16'd0;
            end
        end
    end

    else if (state == WAIT_MV || state == P2_MV) begin
        bi_total_cnt_l0 <= 7'd0;
        bi_row_l0 <= 4'd0;
        bi_col_l0 <= 4'd0;
        pixel_cnt_l0 <= 4'd0;
        h_phase_done_l0 <= 1'b0;
        bi_done_l0 <= 1'b0;
        flag_l0 <= 0;
    end

    else if (state == CALC_BI && !bi_done_l0) begin
        case (interp_mode_l0)
            //===============================================
            // Mode 00: No Interpolation
            //===============================================
            2'b00: begin
                for (integer i = 0; i < 10; i = i + 1) begin
                    for (integer j = 0; j < 9; j = j + 1) begin
                        BI_buffer_L0[i][j] <= BI_buffer_L0[i][j+1];
                    end
                end
                for (integer i = 0; i < 9; i = i + 1) begin
                    BI_buffer_L0[i][9] <= BI_buffer_L0[i+1][0];
                end
                BI_buffer_L0[9][9] <= {8'd0, mem_rdata_l0};
                
                bi_total_cnt_l0 <= bi_total_cnt_l0 + 1'd1;
                
                if (bi_col_l0 == 9) begin
                    bi_col_l0 <= 4'd0;
                    bi_row_l0 <= bi_row_l0 + 1'd1;
                end
                else begin
                    bi_col_l0 <= bi_col_l0 + 1'd1;
                end
                
                if(bi_total_cnt_l0 == 101) begin
                    bi_done_l0 <= 1'b1;
                end
            end

            //===============================================
            // Mode 01: Horizontal Interpolation - L0
            //===============================================
            2'b01: begin
                if(pixel_cnt_l0 == 14) begin
                    pixel_cnt_l0 <= 0;
                    bi_row_l0 <= bi_row_l0 + 1;
                end
                else
                    pixel_cnt_l0 <= pixel_cnt_l0 + 1;
                
                if (pixel_cnt_l0 >= 8 || bi_col_l0 >= 5) begin
                    // Shift BI_buffer and store FIR result
                    for (integer i = 0; i < 10; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L0[i][j] <= BI_buffer_L0[i][j+1];
                        end
                    end
                    for (integer i = 0; i < 9; i = i + 1) begin
                        BI_buffer_L0[i][9] <= BI_buffer_L0[i+1][0];
                    end
                    BI_buffer_L0[9][9] <= {8'd0, fir_clipped_h_v_l0};
                    
                    if (bi_col_l0 == 9) begin
                        // Row complete (generated 10 BI values)
                        bi_col_l0 <= 4'd0;
                        if(bi_row_l0 == 10) 
                            bi_done_l0 <= 1'b1;
                    end
                    else begin
                        bi_col_l0 <= bi_col_l0 + 1'd1;
                    end
                end
            end
            
            //===============================================
            // Mode 10: Vertical Interpolation - L0
            //===============================================
            2'b10: begin
                if (pixel_cnt_l0 == 14) begin
                    pixel_cnt_l0 <= 0;
                    bi_col_l0 <= bi_col_l0 + 1;
                end else 
                    pixel_cnt_l0 <= pixel_cnt_l0 + 1;
                
                if (pixel_cnt_l0 >= 8 || bi_row_l0 >= 5) begin
                    // Shift BI_buffer (column-major) and store FIR result
                    for (integer i = 0; i < 10; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L0[j][i] <= BI_buffer_L0[j+1][i];
                        end
                    end
                    for (integer i = 0; i < 9; i = i + 1) begin
                        BI_buffer_L0[9][i] <= BI_buffer_L0[0][i+1];
                    end
                    BI_buffer_L0[9][9] <= {8'd0, fir_clipped_h_v_l0};
                    
                    if (bi_row_l0 == 9) begin
                        // Column complete
                        bi_row_l0 <= 4'd0;
                        if (bi_col_l0 == 10) begin
                            bi_done_l0 <= 1'b1;
                        end
                    end
                    else begin
                        bi_row_l0 <= bi_row_l0 + 1'd1;
                    end
                end
            end

            //===============================================
            // Mode 11: 2D Interpolation - L0
            //===============================================
            2'b11: begin
                if(pixel_cnt_l0 == 14) begin
                    pixel_cnt_l0 <= 0;
                    bi_row_l0 <= bi_row_l0 + 1;
                end
                else
                    pixel_cnt_l0 <= pixel_cnt_l0 + 1;
                
                if (pixel_cnt_l0 >= 8 || bi_col_l0 >= 5) begin
                    // Shift BI_buffer and store FIR result
                    for (integer i = 10; i < 15; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L0[i][j] <= BI_buffer_L0[i][j+1];
                        end
                    end
                    for (integer i = 10; i < 15; i = i + 1) begin
                        BI_buffer_L0[i][9] <= BI_buffer_L0[i+1][0];
                    end
                    BI_buffer_L0[14][9] <= fir_result_l0;
                    
                    
                    if (bi_col_l0 == 9) begin
                        // Row complete (generated 10 BI values)
                        bi_col_l0 <= 4'd0;
                    end
                    else begin
                        bi_col_l0 <= bi_col_l0 + 1'd1;
                    end
                end

                if (h_phase_done_l0 && (pixel_cnt_l0 >= 8 || bi_col_l0 >= 5))
                    flag_l0 <= 1;
                else
                    flag_l0 <= 0;
            
                if(bi_row_l0 == 5 && bi_col_l0 == 9)
                    h_phase_done_l0 <= 1;

                if(flag_l0) begin
                    for (integer i = 0; i < 10; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L0[i][j] <= BI_buffer_L0[i][j+1];
                        end
                    end
                    for (integer i = 0; i < 9; i = i + 1) begin
                        BI_buffer_L0[i][9] <= BI_buffer_L0[i+1][0];
                    end
                    BI_buffer_L0[9][9] <= {8'd0, fir_clipped_2d_l0};
                    
                    bi_total_cnt_l0 <= bi_total_cnt_l0 + 1'd1;
                    
                    if (bi_total_cnt_l0 == 99) begin
                        bi_done_l0 <= 1'b1;
                    end
                end
            end

            default: begin
                bi_total_cnt_l0 <= 7'd0;
            end
        endcase
    end
end
//=======================================================
// BI Calculation - L1
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bi_total_cnt_l1 <= 7'd0;
        bi_row_l1 <= 4'd0;
        bi_col_l1 <= 4'd0;
        pixel_cnt_l1 <= 4'd0;
        h_phase_done_l1 <= 1'b0;
        bi_done_l1 <= 1'b0;
        flag_l1 <= 1'b0;
        
        for (integer i = 0; i < 10; i = i + 1) begin
            for (integer j = 0; j < 15; j = j + 1) begin
                BI_buffer_L1[i][j] <= 16'd0;
            end
        end
        
    end else if (state == WAIT_MV || state == P2_MV) begin
        bi_total_cnt_l1 <= 7'd0;
        bi_row_l1 <= 4'd0;
        bi_col_l1 <= 4'd0;
        pixel_cnt_l1 <= 4'd0;
        h_phase_done_l1 <= 1'b0;
        bi_done_l1 <= 1'b0;
        flag_l1 <= 1'b0;
        
    end else if (state == CALC_BI && !bi_done_l1) begin
        
        case (interp_mode_l1)
            //===============================================
            // Mode 00: No Interpolation (PIPELINED) - L1
            //===============================================
            2'b00: begin
                for (integer i = 0; i < 10; i = i + 1) begin
                    for (integer j = 0; j < 9; j = j + 1) begin
                        BI_buffer_L1[i][j] <= BI_buffer_L1[i][j+1];
                    end
                end
                for (integer i = 0; i < 9; i = i + 1) begin
                    BI_buffer_L1[i][9] <= BI_buffer_L1[i+1][0];
                end
                BI_buffer_L1[9][9] <= {8'd0, mem_rdata_l1};
                
                bi_total_cnt_l1 <= bi_total_cnt_l1 + 1'd1;

                if (bi_col_l1 == 9) begin
                    bi_col_l1 <= 4'd0;
                    bi_row_l1 <= bi_row_l1 + 1'd1;
                end
                else begin
                    bi_col_l1 <= bi_col_l1 + 1'd1;
                end

                if (bi_total_cnt_l1 == 101) begin
                    bi_done_l1 <= 1'b1;
                end
            end
            
            //===============================================
            // Mode 01: Horizontal Interpolation - L1
            //===============================================
            2'b01: begin
                if (pixel_cnt_l1 == 14) begin
                    pixel_cnt_l1 <= 0;
                    bi_row_l1 <= bi_row_l1 + 1;
                end
                else 
                    pixel_cnt_l1 <= pixel_cnt_l1 + 1;
                
                if (pixel_cnt_l1 >= 8 || bi_col_l1 >= 5) begin
                    // Shift BI_buffer and store FIR result
                    for (integer i = 0; i < 10; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L1[i][j] <= BI_buffer_L1[i][j+1];
                        end
                    end
                    for (integer i = 0; i < 9; i = i + 1) begin
                        BI_buffer_L1[i][9] <= BI_buffer_L1[i+1][0];
                    end
                    BI_buffer_L1[9][9] <= {8'd0, fir_clipped_h_v_l1};
                                       
                    if (bi_col_l1 == 9) begin
                        // Row complete (generated 10 BI values)
                        bi_col_l1 <= 4'd0;
                        if (bi_row_l1 == 10) begin
                            bi_done_l1 <= 1'b1;
                        end
                    end
                    else begin
                        bi_col_l1 <= bi_col_l1 + 1'd1;
                    end
                end
            end
            
            //===============================================
            // Mode 10: Vertical Interpolation - L1
            //===============================================
            2'b10: begin
                if (pixel_cnt_l1 == 14) begin
                    pixel_cnt_l1 <= 0;
                    bi_col_l1 <= bi_col_l1 + 1;
                end
                else 
                    pixel_cnt_l1 <= pixel_cnt_l1 + 1;
                
                if (pixel_cnt_l1 >= 8 || bi_row_l1 >= 5) begin
                    // Shift BI_buffer (column-major) and store FIR result
                    for (integer i = 0; i < 10; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L1[j][i] <= BI_buffer_L1[j+1][i];
                        end
                    end
                    for (integer i = 0; i < 9; i = i + 1) begin
                        BI_buffer_L1[9][i] <= BI_buffer_L1[0][i+1];
                    end
                    BI_buffer_L1[9][9] <= {8'd0, fir_clipped_h_v_l1};
                    
                    if (bi_row_l1 == 9) begin
                        // Column complete
                        bi_row_l1 <= 4'd0;
                        if (bi_col_l1 == 10) begin
                            bi_done_l1 <= 1'b1;
                        end
                    end
                    else begin
                        bi_row_l1 <= bi_row_l1 + 1'd1;
                    end
                end
            end

            //===============================================
            // Mode 11: 2D Interpolation - L1
            //===============================================
            2'b11: begin
                if(pixel_cnt_l1 == 14) begin
                    pixel_cnt_l1 <= 0;
                    bi_row_l1 <= bi_row_l1 + 1;
                end
                else
                    pixel_cnt_l1 <= pixel_cnt_l1 + 1;
                
                if (pixel_cnt_l1 >= 8 || bi_col_l1 >= 5) begin
                    // Shift BI_buffer and store FIR result
                    for (integer i = 10; i < 15; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L1[i][j] <= BI_buffer_L1[i][j+1];
                        end
                    end
                    for (integer i = 10; i < 15; i = i + 1) begin
                        BI_buffer_L1[i][9] <= BI_buffer_L1[i+1][0];
                    end
                    BI_buffer_L1[14][9] <= fir_result_l1;
                    
                    
                    if (bi_col_l1 == 9) begin
                        // Row complete (generated 10 BI values)
                        bi_col_l1 <= 4'd0;
                    end
                    else begin
                        bi_col_l1 <= bi_col_l1 + 1;
                    end
                end

                if (h_phase_done_l1 && (pixel_cnt_l1 >= 8 || bi_col_l1 >= 5))
                    flag_l1 <= 1;
                else
                    flag_l1 <= 0;
            
                if(bi_row_l1 == 5 && bi_col_l1 == 9)
                    h_phase_done_l1 <= 1;

                if(flag_l1) begin
                    for (integer i = 0; i < 10; i = i + 1) begin
                        for (integer j = 0; j < 9; j = j + 1) begin
                            BI_buffer_L1[i][j] <= BI_buffer_L1[i][j+1];
                        end
                    end
                    for (integer i = 0; i < 9; i = i + 1) begin
                        BI_buffer_L1[i][9] <= BI_buffer_L1[i+1][0];
                    end
                    BI_buffer_L1[9][9] <= {8'd0, fir_clipped_2d_l1};
                    
                    bi_total_cnt_l1 <= bi_total_cnt_l1 + 1'd1;
                    
                    if (bi_total_cnt_l1 == 99) begin
                        bi_done_l1 <= 1'b1;
                    end
                end
            end

            default: begin
                bi_total_cnt_l1 <= 7'd0;
            end
        endcase
    end
end


//=======================================================
// Search Pattern Offset Generation (Mirror MVD)
//=======================================================
always @(*) begin
    case (search_point)
        // L0 pattern (normal)
        //4'd0: begin dx_l0 = -2'd1; dy_l0 = -2'd1; end  // Top-left
        4'd0: begin dx_l0 = 0; dy_l0 = 0; end  // Top-left
        4'd1: begin dx_l0 = 0; dy_l0 = 1; end  // Top
        4'd2: begin dx_l0 = 0; dy_l0 = 2; end  // Top-right
        4'd3: begin dx_l0 = 1; dy_l0 = 0; end  // Left
        4'd4: begin dx_l0 = 1; dy_l0 = 1; end  // Center
        4'd5: begin dx_l0 = 1; dy_l0 = 2; end  // Right
        4'd6: begin dx_l0 = 2; dy_l0 = 0; end  // Bottom-left
        4'd7: begin dx_l0 = 2; dy_l0 = 1; end  // Bottom
        4'd8: begin dx_l0 = 2; dy_l0 = 2; end  // Bottom-right
        default: begin dx_l0 = 0; dy_l0 = 0; end
    endcase
    
    // L1 pattern is MIRRORED (see Fig 6)
    case (search_point)
        //4'd0: begin dx_l1 =  2'd1; dy_l1 = -2'd1; end  // Top-right
        4'd0: begin dx_l1 = 2; dy_l1 = 2; end  // Top-right
        4'd1: begin dx_l1 = 2; dy_l1 = 1; end  // Top
        4'd2: begin dx_l1 = 2; dy_l1 = 0; end  // Top-left 
        4'd3: begin dx_l1 = 1; dy_l1 = 2; end  // Right 
        4'd4: begin dx_l1 = 1; dy_l1 = 1; end  // Center
        4'd5: begin dx_l1 = 1; dy_l1 = 0; end  // Left
        4'd6: begin dx_l1 = 0; dy_l1 = 2; end  // Bottom-right
        4'd7: begin dx_l1 = 0; dy_l1 = 1; end  // Bottom
        4'd8: begin dx_l1 = 0; dy_l1 = 0; end  // Bottom-left
        default: begin dx_l1 = 0; dy_l1 = 0; end
    endcase
end

//=======================================================
// Sub-block Position Calculation
//=======================================================
reg [2:0] subblk_y, subblk_x;

always @(*) begin
    case (subblk_cnt)
        2'd0: begin subblk_y = 3'd0; subblk_x = 3'd0; end  // Top-left 4×4
        2'd1: begin subblk_y = 3'd0; subblk_x = 3'd4; end  // Top-right 4×4
        2'd2: begin subblk_y = 3'd4; subblk_x = 3'd0; end  // Bottom-left 4×4
        2'd3: begin subblk_y = 3'd4; subblk_x = 3'd4; end  // Bottom-right 4×4
    endcase
end

//=======================================================
// Stage 1: Subtract (16 values)
//=======================================================
reg signed [8:0] stage1_A_comb [0:15];
reg signed [8:0] stage1_B_comb [0:15];

always @(*) begin
    for (integer i = 0; i < 4; i = i + 1) begin
        for (integer j = 0; j < 4; j = j + 1) begin
            stage1_A_comb[{i[1:0], j[1:0]}] = BI_buffer_L0[dy_l0 + subblk_y + i][dx_l0 + subblk_x + j][7:0];
            stage1_B_comb[{i[1:0], j[1:0]}] = BI_buffer_L1[dy_l1 + subblk_y + i][dx_l1 + subblk_x + j][7:0];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 16; i = i + 1) begin
            stage1_diff[i] <= 9'd0;
        end
        stage1_valid <= 1'b0;
    end
    else if (state == CALC_SATD && satd_cycle_cnt < 36) begin
        // Load 4×4 sub-block and subtract L0 - L1
        for (integer i = 0; i < 16; i = i + 1) begin
            stage1_diff[i] <= stage1_A_comb[i] - stage1_B_comb[i];
        end
        stage1_valid <= 1'b1;
    end
    else begin
        stage1_valid <= 1'b0;
    end
end

//=======================================================
// Stage 2: First Hadamard Transform (H)
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 16; i = i + 1) begin
            stage2_h[i] <= 12'd0;
        end
        stage2_valid <= 1'b0;
    end

    else begin
        if (stage1_valid) begin
            // Apply Hadamard on rows
            for (integer i = 0; i < 4; i = i + 1) begin
                stage2_h[i*4 + 0] <= stage1_diff[i*4+0] + stage1_diff[i*4+1] + stage1_diff[i*4+2] + stage1_diff[i*4+3];
                stage2_h[i*4 + 1] <= stage1_diff[i*4+0] + stage1_diff[i*4+1] - stage1_diff[i*4+2] - stage1_diff[i*4+3];
                stage2_h[i*4 + 2] <= stage1_diff[i*4+0] - stage1_diff[i*4+1] - stage1_diff[i*4+2] + stage1_diff[i*4+3];
                stage2_h[i*4 + 3] <= stage1_diff[i*4+0] - stage1_diff[i*4+1] + stage1_diff[i*4+2] - stage1_diff[i*4+3];
            end
            stage2_valid <= 1'b1;
        end else begin
            stage2_valid <= 1'b0;
        end
    end
end

//=======================================================
// Stage 3: Second Hadamard Transform (HT)
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 16; i = i + 1) begin
            stage3_ht[i] <= 14'd0;
        end
        stage3_valid <= 1'b0;
        
    end else begin
        if (stage2_valid) begin
            // Apply Hadamard on columns
            for (integer j = 0; j < 4; j = j + 1) begin
                stage3_ht[j]    <= stage2_h[j] + stage2_h[j+4] + stage2_h[j+8] + stage2_h[j+12];
                stage3_ht[j+4]  <= stage2_h[j] + stage2_h[j+4] - stage2_h[j+8] - stage2_h[j+12];
                stage3_ht[j+8]  <= stage2_h[j] - stage2_h[j+4] - stage2_h[j+8] + stage2_h[j+12];
                stage3_ht[j+12] <= stage2_h[j] - stage2_h[j+4] + stage2_h[j+8] - stage2_h[j+12];
            end
            stage3_valid <= 1'b1;
        end
        else begin
            stage3_valid <= 1'b0;
        end
    end
end

//=======================================================
// Stage 4: Absolute Value AND Partial Sum (16 -> 4)
//=======================================================
reg [13:0] abs_val [0:15];

always @(*) begin
    // Take absolute values
    for (integer i = 0; i < 16; i = i + 1) begin
        abs_val[i] = stage3_ht[i][13] ? -stage3_ht[i] : stage3_ht[i];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 4; i = i + 1) begin
            stage4_partial[i] <= 16'd0;
        end
        stage4_valid <= 1'b0;
    end
    else begin
        if (stage3_valid) begin
            // Sum groups of 4 (reduce from 16 to 4 values)
            stage4_partial[0] <= abs_val[0] + abs_val[1] + abs_val[2] + abs_val[3];
            stage4_partial[1] <= abs_val[4] + abs_val[5] + abs_val[6] + abs_val[7];
            stage4_partial[2] <= abs_val[8] + abs_val[9] + abs_val[10] + abs_val[11];
            stage4_partial[3] <= abs_val[12] + abs_val[13] + abs_val[14] + abs_val[15];
            stage4_valid <= 1'b1;
        end
        else begin
            stage4_valid <= 1'b0;
        end
    end
end

//=======================================================
// Stage 5: Final Sum (4 -> 1)
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stage5_satd <= 18'd0;
        stage5_valid <= 1'b0;
        
    end else begin
        if (stage4_valid) begin
            // Final sum of 4 partial sums
            stage5_satd <= stage4_partial[0] + stage4_partial[1] + stage4_partial[2] + stage4_partial[3];
            stage5_valid <= 1'b1;
        end
        else begin
            stage5_valid <= 1'b0;
        end
    end
end


//=======================================================
// SATD Accumulation and Minimum Tracking
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_point_satd <= 24'd0;
        subblk_cnt <= 2'd0;
        search_point <= 4'd0;
        satd_cycle_cnt <= 6'd0;
        min_satd <= 24'hFFFFFF;  // Max value
        min_point <= 4'd0;
    end
    else if (state == CALC_BI && next_state == CALC_SATD) begin
        // Reset when entering SATD state
        current_point_satd <= 24'd0;
        subblk_cnt <= 2'd0;
        search_point <= 4'd0;
        satd_cycle_cnt <= 6'd0;
        min_satd <= 24'hFFFFFF;
        min_point <= 4'd0;
    end

    else if (state == CALC_SATD) begin
        satd_cycle_cnt <= satd_cycle_cnt + 1'd1;
        subblk_cnt <= subblk_cnt + 1'd1;
        if (subblk_cnt == 2'd3) begin
            subblk_cnt <= 2'd0;
            search_point <= search_point + 1'd1;
        end
        
        // Collect results (starting from cycle 5 when pipeline fills)
        if (stage5_valid) begin
            // Accumulate sub-block SATD to current search point
            current_point_satd <= current_point_satd + stage5_satd;
            
            // Check if this completes a search point (every 4th sub-block)
            if (subblk_cnt == 0) begin  // previous point is done
                if (current_point_satd + stage5_satd < min_satd) begin
                    min_satd <= current_point_satd + stage5_satd;
                    min_point <= search_point - 2;
                end 
                current_point_satd <= 24'd0;
            end
        end
    end
end


//=======================================================
// Point 1 
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        point_1_done <= 1'b0;
        out_point_1 <= 28'd0;
    end
    else begin
        if (state == WAIT_MV) begin
            point_1_done <= 0;
            out_point_1 <= 0;
        end
        else if(state == CALC_SATD && satd_cycle_cnt == 41) begin
            point_1_done <= 1;
            out_point_1 <= {min_point[3:0], min_satd[23:0]};
        end
    end
end


//=======================================================
// Output Control
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        output_cnt <= 6'd0;
    end
    else if ((state == CALC_SATD && point_1_done && (satd_cycle_cnt >= 14)) || state == OUTPUT) begin
        if (output_cnt == 27)
            output_cnt <= 6'd0;
        else
            output_cnt <= output_cnt + 1;
    end
    else 
        output_cnt <= 6'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pattern_cnt <= 6'd0;
    end
    else begin
        if (state == OUTPUT && output_cnt == 27) begin
            pattern_cnt <= pattern_cnt + 1'd1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_sad <= 0;
        out_valid <= 0;
    end
    else begin
        out_sad <= next_out_sad;
        out_valid <= next_out_valid;
    end
end

always @(*) begin
    next_out_sad = 0;
    next_out_valid = 0;
    if ((state == CALC_SATD && point_1_done && (satd_cycle_cnt >= 14)) || state == OUTPUT) begin
        next_out_sad = out_point_1[output_cnt];
        next_out_valid = 1;
    end
end

//=======================================================
// SRAM Instances
//=======================================================
MEM_L0 MEM_L0_inst (
    .A0(mem_addr_l0[0]),  .A1(mem_addr_l0[1]),  .A2(mem_addr_l0[2]),  .A3(mem_addr_l0[3]),
    .A4(mem_addr_l0[4]),  .A5(mem_addr_l0[5]),  .A6(mem_addr_l0[6]),  .A7(mem_addr_l0[7]),
    .A8(mem_addr_l0[8]),  .A9(mem_addr_l0[9]),  .A10(mem_addr_l0[10]), .A11(mem_addr_l0[11]),
    .A12(mem_addr_l0[12]), .A13(mem_addr_l0[13]),
    
    .DO0(mem_rdata_l0[0]), .DO1(mem_rdata_l0[1]), .DO2(mem_rdata_l0[2]), .DO3(mem_rdata_l0[3]),
    .DO4(mem_rdata_l0[4]), .DO5(mem_rdata_l0[5]), .DO6(mem_rdata_l0[6]), .DO7(mem_rdata_l0[7]),
    
    .DI0(mem_wdata[0]), .DI1(mem_wdata[1]), .DI2(mem_wdata[2]), .DI3(mem_wdata[3]),
    .DI4(mem_wdata[4]), .DI5(mem_wdata[5]), .DI6(mem_wdata[6]), .DI7(mem_wdata[7]),
    
    .CK(clk), .WEB(~mem_we_l0), .OE(1'b1), .CS(1'b1)
);

MEM_L1 MEM_L1_inst (
    .A0(mem_addr_l1[0]),  .A1(mem_addr_l1[1]),  .A2(mem_addr_l1[2]),  .A3(mem_addr_l1[3]),
    .A4(mem_addr_l1[4]),  .A5(mem_addr_l1[5]),  .A6(mem_addr_l1[6]),  .A7(mem_addr_l1[7]),
    .A8(mem_addr_l1[8]),  .A9(mem_addr_l1[9]),  .A10(mem_addr_l1[10]), .A11(mem_addr_l1[11]),
    .A12(mem_addr_l1[12]), .A13(mem_addr_l1[13]),
    
    .DO0(mem_rdata_l1[0]), .DO1(mem_rdata_l1[1]), .DO2(mem_rdata_l1[2]), .DO3(mem_rdata_l1[3]),
    .DO4(mem_rdata_l1[4]), .DO5(mem_rdata_l1[5]), .DO6(mem_rdata_l1[6]), .DO7(mem_rdata_l1[7]),
    
    .DI0(mem_wdata[0]), .DI1(mem_wdata[1]), .DI2(mem_wdata[2]), .DI3(mem_wdata[3]),
    .DI4(mem_wdata[4]), .DI5(mem_wdata[5]), .DI6(mem_wdata[6]), .DI7(mem_wdata[7]),
    
    .CK(clk), .WEB(~mem_we_l1), .OE(1'b1), .CS(1'b1)
);

endmodule