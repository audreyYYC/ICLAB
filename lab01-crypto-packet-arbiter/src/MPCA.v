module MPCA(
    // Input signals
    input [127:0] packets,
    input  [11:0] channel_load,
    input   [8:0] channel_capacity,
    input  [63:0] KEY,
    // Output signals
    output reg [15:0] grant_channel
);

//================================================================
//    Decrypting 
//================================================================
wire [15:0] k0 = KEY[15:0];
wire [15:0] l0 = KEY[31:16];
wire [15:0] l1 = KEY[47:32];
wire [15:0] l2 = KEY[63:48];

reg [15:0] k1, k2, k3;
reg [15:0] k2_temp, k3_temp;
always @(*) begin
    k1 = {k0[6:0], k0[15:7]} + l0;

    k2_temp = {k1[6:0], k1[15:7]} + l1;
    if (k2_temp[0]) 
        k2 = {k2_temp[15:1], 1'b0};
    else
        k2 = {k2_temp[15:1], 1'b1};

    k3_temp = {k2[6:0], k2[15:7]} + l2;
    if (k3_temp[1]) 
        k3 = {k3_temp[15:2], 1'b0, k3_temp[0]};
    else
        k3 = {k3_temp[15:2], 1'b1, k3_temp[0]};
end

wire [15:0] b0_x4 = packets[15:0];
wire [15:0] b0_y4 = packets[31:16];
wire [15:0] b1_x4 = packets[47:32];
wire [15:0] b1_y4 = packets[63:48];
wire [15:0] b2_x4 = packets[79:64];
wire [15:0] b2_y4 = packets[95:80];
wire [15:0] b3_x4 = packets[111:96];
wire [15:0] b3_y4 = packets[127:112];

//block 0
wire [15:0] b0_y3_temp = b0_x4 ^ b0_y4;
wire [15:0] b0_y3 = {b0_y3_temp[1:0], b0_y3_temp[15:2]};
wire [15:0] b0_x3_temp = b0_x4 ^ k3;
wire [15:0] b0_x3_temp_1 = $signed(b0_x3_temp - b0_y3);
wire [15:0] b0_x3 = {b0_x3_temp_1[8:0], b0_x3_temp_1[15:9]};

wire [15:0] b0_y2_temp = b0_x3 ^ b0_y3;
wire [15:0] b0_y2 = {b0_y2_temp[1:0], b0_y2_temp[15:2]};
wire [15:0] b0_x2_temp = b0_x3 ^ k2;
wire [15:0] b0_x2_temp_1 = $signed(b0_x2_temp - b0_y2);
wire [15:0] b0_x2 = {b0_x2_temp_1[8:0], b0_x2_temp_1[15:9]};

wire [15:0] b0_y1_temp = b0_x2 ^ b0_y2;
wire [15:0] b0_y1 = {b0_y1_temp[1:0], b0_y1_temp[15:2]};
wire [15:0] b0_x1_temp = $signed(b0_x2 ^ k1) - b0_y1;
wire [15:0] b0_x1 = {b0_x1_temp[8:0], b0_x1_temp[15:9]};

wire [15:0] b0_y0_temp = b0_x1 ^ b0_y1;
wire [15:0] p1 = {b0_y0_temp[1:0], b0_y0_temp[15:2]};
wire [15:0] b0_x0_temp = $signed(b0_x1 ^ k0) - p1;
wire [15:0] p0 = {b0_x0_temp[8:0], b0_x0_temp[15:9]};

//block 1
wire [15:0] b1_y3_temp = b1_x4 ^ b1_y4;
wire [15:0] b1_y3 = {b1_y3_temp[1:0], b1_y3_temp[15:2]};
wire [15:0] b1_x3_temp = $signed(b1_x4 ^ k3) - b1_y3;
wire [15:0] b1_x3 = {b1_x3_temp[8:0], b1_x3_temp[15:9]};

wire [15:0] b1_y2_temp = b1_x3 ^ b1_y3;
wire [15:0] b1_y2 = {b1_y2_temp[1:0], b1_y2_temp[15:2]};
wire [15:0] b1_x2_temp = $signed(b1_x3 ^ k2) - b1_y2;
wire [15:0] b1_x2 = {b1_x2_temp[8:0], b1_x2_temp[15:9]};

wire [15:0] b1_y1_temp = b1_x2 ^ b1_y2;
wire [15:0] b1_y1 = {b1_y1_temp[1:0], b1_y1_temp[15:2]};
wire [15:0] b1_x1_temp = $signed(b1_x2 ^ k1) - b1_y1;
wire [15:0] b1_x1 = {b1_x1_temp[8:0], b1_x1_temp[15:9]};

wire [15:0] b1_y0_temp = b1_x1 ^ b1_y1;
wire [15:0] p3 = {b1_y0_temp[1:0], b1_y0_temp[15:2]};
wire [15:0] b1_x0_temp = $signed(b1_x1 ^ k0) - p3;
wire [15:0] p2 = {b1_x0_temp[8:0], b1_x0_temp[15:9]};

//block 2
wire [15:0] b2_y3_temp = b2_x4 ^ b2_y4;
wire [15:0] b2_y3 = {b2_y3_temp[1:0], b2_y3_temp[15:2]};
wire [15:0] b2_x3_temp = $signed(b2_x4 ^ k3) - b2_y3;
wire [15:0] b2_x3 = {b2_x3_temp[8:0], b2_x3_temp[15:9]};

wire [15:0] b2_y2_temp = b2_x3 ^ b2_y3;
wire [15:0] b2_y2 = {b2_y2_temp[1:0], b2_y2_temp[15:2]};
wire [15:0] b2_x2_temp = $signed(b2_x3 ^ k2) - b2_y2;
wire [15:0] b2_x2 = {b2_x2_temp[8:0], b2_x2_temp[15:9]};

wire [15:0] b2_y1_temp = b2_x2 ^ b2_y2;
wire [15:0] b2_y1 = {b2_y1_temp[1:0], b2_y1_temp[15:2]};
wire [15:0] b2_x1_temp = $signed(b2_x2 ^ k1) - b2_y1;
wire [15:0] b2_x1 = {b2_x1_temp[8:0], b2_x1_temp[15:9]};

wire [15:0] b2_y0_temp = b2_x1 ^ b2_y1;
wire [15:0] p5 = {b2_y0_temp[1:0], b2_y0_temp[15:2]};
wire [15:0] b2_x0_temp = $signed(b2_x1 ^ k0) - p5;
wire [15:0] p4 = {b2_x0_temp[8:0], b2_x0_temp[15:9]};

//block 3
wire [15:0] b3_y3_temp = b3_x4 ^ b3_y4;
wire [15:0] b3_y3 = {b3_y3_temp[1:0], b3_y3_temp[15:2]};
wire [15:0] b3_x3_temp = $signed(b3_x4 ^ k3) - b3_y3;
wire [15:0] b3_x3 = {b3_x3_temp[8:0], b3_x3_temp[15:9]};

wire [15:0] b3_y2_temp = b3_x3 ^ b3_y3;
wire [15:0] b3_y2 = {b3_y2_temp[1:0], b3_y2_temp[15:2]};
wire [15:0] b3_x2_temp = $signed(b3_x3 ^ k2) - b3_y2;
wire [15:0] b3_x2 = {b3_x2_temp[8:0], b3_x2_temp[15:9]};

wire [15:0] b3_y1_temp = b3_x2 ^ b3_y2;
wire [15:0] b3_y1 = {b3_y1_temp[1:0], b3_y1_temp[15:2]};
wire [15:0] b3_x1_temp = $signed(b3_x2 ^ k1) - b3_y1;
wire [15:0] b3_x1 = {b3_x1_temp[8:0], b3_x1_temp[15:9]};

wire [15:0] b3_y0_temp = b3_x1 ^ b3_y1;
wire [15:0] p7 = {b3_y0_temp[1:0], b3_y0_temp[15:2]};
wire [15:0] b3_x0_temp = $signed(b3_x1 ^ k0) - p7;
wire [15:0] p6 = {b3_x0_temp[8:0], b3_x0_temp[15:9]};


//================================================================
//    Priority Score Calculation
//================================================================
reg [6:0] score[7:0];
always @(*) begin
    if (p0[1]) 
        score[0] = ($signed(p0[14:13]) << 2) - ($signed(p0[12:9]) << 1) - ($signed(p0[8:7]) * 3) + $signed(p0[4:2]) + 7;
    else 
        score[0] = (p0[14:13] << 2) - (p0[12:9] << 1) - (p0[8:7] * 3) + p0[4:2] + 7;
end
always @(*) begin
    if (p1[1]) 
        score[1] = ($signed(p1[14:13]) << 2) - ($signed(p1[12:9]) << 1) - ($signed(p1[8:7]) * 3) + $signed(p1[4:2]) + 7;
    else
        score[1] = (p1[14:13] << 2) - (p1[12:9] << 1) - (p1[8:7] * 3) + p1[4:2] + 7;
end
always @(*) begin
    if (p2[1]) 
        score[2] = ($signed(p2[14:13]) << 2) - ($signed(p2[12:9]) << 1) - ($signed(p2[8:7]) * 3) + $signed(p2[4:2]) + 7;
    else
        score[2] = (p2[14:13] << 2) - (p2[12:9] << 1) - (p2[8:7] * 3) + p2[4:2] + 7;
end
always @(*) begin
    if (p3[1]) 
        score[3] = ($signed(p3[14:13]) << 2) - ($signed(p3[12:9]) << 1) - ($signed(p3[8:7]) * 3) + $signed(p3[4:2]) + 7;
    else
        score[3] = (p3[14:13] << 2) - (p3[12:9] << 1) - (p3[8:7] * 3) + p3[4:2] + 7;
end
always @(*) begin
    if (p4[1]) 
        score[4] = ($signed(p4[14:13]) << 2) - ($signed(p4[12:9]) << 1) - ($signed(p4[8:7]) * 3) + $signed(p4[4:2]) + 7;
    else
        score[4] = (p4[14:13] << 2) - (p4[12:9] << 1) - (p4[8:7] * 3) + p4[4:2] + 7;
end
always @(*) begin
    if (p5[1]) 
        score[5] = ($signed(p5[14:13]) << 2) - ($signed(p5[12:9]) << 1) - ($signed(p5[8:7]) * 3) + $signed(p5[4:2]) + 7;
    else
        score[5] = (p5[14:13] << 2) - (p5[12:9] << 1) - (p5[8:7] * 3) + p5[4:2] + 7;
end
always @(*) begin
    if (p6[1]) 
        score[6] = ($signed(p6[14:13]) << 2) - ($signed(p6[12:9]) << 1) - ($signed(p6[8:7]) * 3) + $signed(p6[4:2]) + 7;
    else
        score[6] = (p6[14:13] << 2) - (p6[12:9] << 1) - (p6[8:7] * 3) + p6[4:2] + 7;
end
always @(*) begin
    if (p7[1]) 
        score[7] = ($signed(p7[14:13]) << 2) - ($signed(p7[12:9]) << 1) - ($signed(p7[8:7]) * 3) + $signed(p7[4:2]) + 7;
    else
        score[7] = (p7[14:13] << 2) - (p7[12:9] << 1) - (p7[8:7] * 3) + p7[4:2] + 7;
end

//================================================================
//    Sort
//================================================================
wire [25:0] data  [7:0];
wire [25:0] stage1[7:0];
wire [25:0] stage2[7:0];
wire [25:0] stage3[7:0];
wire [25:0] stage4[7:0];
wire [25:0] stage5[7:0];
wire [25:0] stage6[7:0];

assign data[0] = {3'd0, p0, score[0]};
assign data[1] = {3'd1, p1, score[1]};
assign data[2] = {3'd2, p2, score[2]};
assign data[3] = {3'd3, p3, score[3]};
assign data[4] = {3'd4, p4, score[4]};
assign data[5] = {3'd5, p5, score[5]};
assign data[6] = {3'd6, p6, score[6]};
assign data[7] = {3'd7, p7, score[7]};

// Stage 1
compare_swap cs1_0(.a(data[0]), .b(data[1]), .hi(stage1[1]), .lo(stage1[0]));
compare_swap cs1_1(.a(data[2]), .b(data[3]), .hi(stage1[2]), .lo(stage1[3]));
compare_swap cs1_2(.a(data[4]), .b(data[5]), .hi(stage1[5]), .lo(stage1[4]));
compare_swap cs1_3(.a(data[6]), .b(data[7]), .hi(stage1[6]), .lo(stage1[7]));
// Stage 2
compare_swap cs2_0(.a(stage1[0]), .b(stage1[2]), .hi(stage2[2]), .lo(stage2[0]));
compare_swap cs2_1(.a(stage1[1]), .b(stage1[3]), .hi(stage2[3]), .lo(stage2[1]));
compare_swap cs2_2(.a(stage1[4]), .b(stage1[6]), .hi(stage2[4]), .lo(stage2[6]));
compare_swap cs2_3(.a(stage1[5]), .b(stage1[7]), .hi(stage2[5]), .lo(stage2[7]));
// Stage 3
compare_swap cs3_0(.a(stage2[0]), .b(stage2[1]), .hi(stage3[1]), .lo(stage3[0]));
compare_swap cs3_1(.a(stage2[2]), .b(stage2[3]), .hi(stage3[3]), .lo(stage3[2]));
compare_swap cs3_2(.a(stage2[4]), .b(stage2[5]), .hi(stage3[4]), .lo(stage3[5]));
compare_swap cs3_3(.a(stage2[6]), .b(stage2[7]), .hi(stage3[6]), .lo(stage3[7]));
// Stage 4
compare_swap cs4_0(.a(stage3[0]), .b(stage3[4]), .hi(stage4[0]), .lo(stage4[4]));
compare_swap cs4_1(.a(stage3[1]), .b(stage3[5]), .hi(stage4[1]), .lo(stage4[5]));
compare_swap cs4_2(.a(stage3[2]), .b(stage3[6]), .hi(stage4[2]), .lo(stage4[6]));
compare_swap cs4_3(.a(stage3[3]), .b(stage3[7]), .hi(stage4[3]), .lo(stage4[7]));
// Stage 5
compare_swap cs5_0(.a(stage4[0]), .b(stage4[2]), .hi(stage5[0]), .lo(stage5[2]));
compare_swap cs5_1(.a(stage4[1]), .b(stage4[3]), .hi(stage5[1]), .lo(stage5[3]));
compare_swap cs5_2(.a(stage4[4]), .b(stage4[6]), .hi(stage5[4]), .lo(stage5[6]));
compare_swap cs5_3(.a(stage4[5]), .b(stage4[7]), .hi(stage5[5]), .lo(stage5[7]));
// Stage 6
compare_swap cs6_0(.a(stage5[0]), .b(stage5[1]), .hi(stage6[0]), .lo(stage6[1]));
compare_swap cs6_1(.a(stage5[2]), .b(stage5[3]), .hi(stage6[2]), .lo(stage6[3]));
compare_swap cs6_2(.a(stage5[4]), .b(stage5[5]), .hi(stage6[4]), .lo(stage6[5]));
compare_swap cs6_3(.a(stage5[6]), .b(stage5[7]), .hi(stage6[6]), .lo(stage6[7]));

wire [2:0] sorted_idx [7:0];
assign sorted_idx[0] = stage6[0][25:23];
assign sorted_idx[1] = stage6[1][25:23];
assign sorted_idx[2] = stage6[2][25:23];
assign sorted_idx[3] = stage6[3][25:23];
assign sorted_idx[4] = stage6[4][25:23];
assign sorted_idx[5] = stage6[5][25:23];
assign sorted_idx[6] = stage6[6][25:23];
assign sorted_idx[7] = stage6[7][25:23];

wire [15:0] sorted_p [7:0];
assign sorted_p[0] = stage6[0][22:7];
assign sorted_p[1] = stage6[1][22:7];
assign sorted_p[2] = stage6[2][22:7];
assign sorted_p[3] = stage6[3][22:7];
assign sorted_p[4] = stage6[4][22:7];
assign sorted_p[5] = stage6[5][22:7];
assign sorted_p[6] = stage6[6][22:7];
assign sorted_p[7] = stage6[7][22:7];

//================================================================
//    Channel Allocation
//================================================================
reg [1:0] alloc[7:0]; //sorted order
reg [3:0] current_load[2:0][8:0];
wire [3:0] ini [2:0];
assign ini[0] = channel_load[3:0];
assign ini[1] = channel_load[7:4];
assign ini[2] = channel_load[11:8];
wire [2:0] cap[2:0];
assign cap[0] = channel_capacity[2:0];
assign cap[1] = channel_capacity[5:3];
assign cap[2] = channel_capacity[8:6];

reg [1:0] search_pivot;
reg [1:0] fallback_channel;
reg fallback_success;

always @(*) begin
    reg [1:0] current_pivot;
    reg all_channels_full;
    reg fallback_occurred;
    current_pivot = 0;
    fallback_occurred = 0;
    all_channels_full = 0;
    for (integer i = 0; i < 9 ; i = i + 1) begin
        current_load[0][i] = 0;
        current_load[1][i] = 0;
        current_load[2][i] = 0;
    end
    
    for (integer i = 0; i < 8; i = i + 1) begin
        reg req_valid_i;
        reg [1:0] prefer_ch_i;
        current_load[0][i+1] = current_load[0][i];
        current_load[1][i+1] = current_load[1][i];
        current_load[2][i+1] = current_load[2][i];
        case (i)
            0: begin req_valid_i = sorted_p[0][15]; prefer_ch_i = sorted_p[0][6:5]; end
            1: begin req_valid_i = sorted_p[1][15]; prefer_ch_i = sorted_p[1][6:5]; end
            2: begin req_valid_i = sorted_p[2][15]; prefer_ch_i = sorted_p[2][6:5]; end
            3: begin req_valid_i = sorted_p[3][15]; prefer_ch_i = sorted_p[3][6:5]; end
            4: begin req_valid_i = sorted_p[4][15]; prefer_ch_i = sorted_p[4][6:5]; end
            5: begin req_valid_i = sorted_p[5][15]; prefer_ch_i = sorted_p[5][6:5]; end
            6: begin req_valid_i = sorted_p[6][15]; prefer_ch_i = sorted_p[6][6:5]; end
            7: begin req_valid_i = sorted_p[7][15]; prefer_ch_i = sorted_p[7][6:5]; end
            default: begin req_valid_i = 1'b0; prefer_ch_i = 2'b00; end
        endcase
        
        if (all_channels_full || !req_valid_i) begin
            alloc[i] = 2'b11;
        end
        else begin
            reg ch0_avail, ch1_avail, ch2_avail, prefer_avail;
            ch0_avail = (current_load[0][i] < cap[0]);
            ch1_avail = (current_load[1][i] < cap[1]);
            ch2_avail = (current_load[2][i] < cap[2]);
            
            case (prefer_ch_i)
                2'd0: prefer_avail = ch0_avail;
                2'd1: prefer_avail = ch1_avail;
                2'd2: prefer_avail = ch2_avail;
                default: prefer_avail = 0;
            endcase
            
            if (prefer_avail) begin //Preferred
                alloc[i] = prefer_ch_i;
                case (prefer_ch_i)
                    2'd0: begin 
                        current_load[0][i+1] = current_load[0][i] + 1;
                        current_load[1][i+1] = current_load[1][i];
                        current_load[2][i+1] = current_load[2][i];
                    end
                    2'd1: begin 
                        current_load[0][i+1] = current_load[0][i];
                        current_load[1][i+1] = current_load[1][i] + 1;
                        current_load[2][i+1] = current_load[2][i];
                    end
                    2'd2: begin 
                        current_load[0][i+1] = current_load[0][i];
                        current_load[1][i+1] = current_load[1][i];
                        current_load[2][i+1] = current_load[2][i] + 1;
                    end
                    default: ;
                endcase
            end
            else begin // Fallback
                if (fallback_occurred) begin
                    search_pivot = current_pivot;
                end else begin
                    search_pivot = prefer_ch_i;
                    fallback_occurred = 1;
                end

                case (search_pivot)
                    2'd0: begin //0 -> 1 -> 2
                        if (ch0_avail) begin
                            alloc[i] = 0;
                            current_load[0][i+1] = current_load[0][i] + 1;
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 1;
                        end
                        else if (ch1_avail) begin
                            alloc[i] = 1;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i] + 1;
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 1;
                        end
                        else if (ch2_avail) begin
                            alloc[i] = 2;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i] + 1;
                            current_pivot = 1;
                        end
                        else begin
                            alloc[i] = 2'b11;
                            all_channels_full = 1;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 1;
                        end
                    end
                    2'd1: begin //1 -> 2 -> 0
                        if (ch1_avail) begin
                            alloc[i] = 1;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i] + 1;
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 2;
                        end
                        else if (ch2_avail) begin
                            alloc[i] = 2;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i] + 1;
                            current_pivot = 2;
                        end
                        else if (ch0_avail) begin
                            alloc[i] = 0;
                            current_load[0][i+1] = current_load[0][i] + 1;
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 2;
                        end
                        else begin
                            alloc[i] = 2'b11;
                            all_channels_full = 1;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 2;
                        end
                    end
                    2'd2: begin //2 -> 0 -> 1
                        if (ch2_avail) begin
                            alloc[i] = 2;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i] + 1;
                            current_pivot = 0;
                        end
                        else if (ch0_avail) begin
                            alloc[i] = 0;
                            current_load[0][i+1] = current_load[0][i] + 1;
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 0;
                        end
                        else if (ch1_avail) begin
                            alloc[i] = 1;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i] + 1;
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 0;
                        end
                        else begin
                            alloc[i] = 2'b11;
                            all_channels_full = 1;
                            current_load[0][i+1] = current_load[0][i];
                            current_load[1][i+1] = current_load[1][i];
                            current_load[2][i+1] = current_load[2][i];
                            current_pivot = 0;
                        end
                    end
                    default: alloc[i] = 2'b11;
                endcase
            end
        end
    end
end

//================================================================
//    Mask
//================================================================
reg [7:0] mask_failed;
reg [4:0] mask_score_raw;
reg [3:0] mask_score, threshold;
reg [1:0] allocated_ch;
reg [3:0] channel_load_ch;
reg [3:0] priority_masked, src_hint_xor;
reg [1:0] prefer_ch;
reg [2:0] src_hint;
reg signed [15:0] priority_score;

always @(*) begin
    for (integer i = 0; i < 8; i = i + 1) begin
        allocated_ch = alloc[i];
        case (allocated_ch)
            2'd0: channel_load_ch = ini[0];
            2'd1: channel_load_ch = ini[1];
            2'd2: channel_load_ch = ini[2];
            default: channel_load_ch = 0;
        endcase
        
        if (allocated_ch == 2'b11) begin
            mask_failed[i] = 0;
        end
        else begin
            case (i)
                0: begin priority_score = stage6[0][6:0]; prefer_ch = sorted_p[0][6:5]; src_hint = sorted_p[0][4:2]; end
                1: begin priority_score = stage6[1][6:0]; prefer_ch = sorted_p[1][6:5]; src_hint = sorted_p[1][4:2]; end
                2: begin priority_score = stage6[2][6:0]; prefer_ch = sorted_p[2][6:5]; src_hint = sorted_p[2][4:2]; end
                3: begin priority_score = stage6[3][6:0]; prefer_ch = sorted_p[3][6:5]; src_hint = sorted_p[3][4:2]; end
                4: begin priority_score = stage6[4][6:0]; prefer_ch = sorted_p[4][6:5]; src_hint = sorted_p[4][4:2]; end
                5: begin priority_score = stage6[5][6:0]; prefer_ch = sorted_p[5][6:5]; src_hint = sorted_p[5][4:2]; end
                6: begin priority_score = stage6[6][6:0]; prefer_ch = sorted_p[6][6:5]; src_hint = sorted_p[6][4:2]; end
                7: begin priority_score = stage6[7][6:0]; prefer_ch = sorted_p[7][6:5]; src_hint = sorted_p[7][4:2]; end
                default: begin priority_score = 0; prefer_ch = 0; src_hint = 0; end
            endcase
            
            priority_masked = {priority_score[2:1], 1'b0};
            src_hint_xor = {src_hint[2], !src_hint[1], !src_hint[0]};
            mask_score_raw = priority_masked + prefer_ch + src_hint_xor + channel_load_ch;

            case (mask_score_raw)
                5'd1, 5'd11, 5'd21:    mask_score = 1;
                5'd2, 5'd12, 5'd22:    mask_score = 2;
                5'd3, 5'd13, 5'd23:    mask_score = 3;
                5'd4, 5'd14, 5'd24:    mask_score = 4;
                5'd5, 5'd15, 5'd25:    mask_score = 5;
                5'd6, 5'd16, 5'd26:    mask_score = 6;
                5'd7, 5'd17, 5'd27:    mask_score = 7;
                5'd8, 5'd18, 5'd28:    mask_score = 8;
                5'd9, 5'd19, 5'd29:    mask_score = 9;
                default:    mask_score = 0;
            endcase
            case (channel_load_ch)
                4'd0, 4'd1, 4'd2: threshold = 7;
                4'd3, 4'd4, 4'd5: threshold = 8;
                4'd6, 4'd7, 4'd8: threshold = 9;
                4'd9, 4'd10, 4'd11: threshold = 10;
                4'd12, 4'd13, 4'd14: threshold = 11;
                4'd15: threshold = 12;
                default: threshold = 7;
            endcase
            mask_failed[i] = (mask_score >= threshold);
        end
    end
end

//================================================================
//    Global Rebalance
//================================================================
reg [4:0] total_load[2:0];
reg [1:0] alloc_re[7:0];
reg [1:0] final_alloc[7:0]; //idx order
reg done;

always @(*) begin
    total_load[0] = ini[0] + current_load[0][8];
    total_load[1] = ini[1] + current_load[1][8];
    total_load[2] = ini[2] + current_load[2][8];

    for (integer i = 0 ; i < 8; i = i+1) begin
        alloc_re[i] = alloc[i];
    end
    done= 0;

    if (total_load[0] == total_load[1] && total_load[1] == total_load[2]) begin // No rebalance

    end
    else if (total_load[0] >= total_load[1] && total_load[0] >= total_load[2]) begin //Channel 0 rebalance
        for (integer i = 7; i >= 0; i = i - 1) begin
            if ((alloc_re[i] == 0) && !mask_failed[i] && !done) begin
                if (cap[1] > current_load[1][8] && (total_load[1] < 15)) 
                    alloc_re[i] = 1;
                else if (cap[2] > current_load[2][8] && (total_load[2] < 15)) 
                    alloc_re[i] = 2;
                else
                    alloc_re[i] = 3;

                done = 1;
            end
        end
    end
    else if (total_load[1] >= total_load[2]) begin //Channel 1 rebalance
        for (integer i = 7; i >= 0; i = i - 1) begin
            if ((alloc_re[i] == 1) && !mask_failed[i] && !done) begin
                if (cap[2] > current_load[2][8] && (total_load[2] < 15)) 
                    alloc_re[i] = 2;
                else if (cap[0] > current_load[0][8] && (total_load[0] < 15)) 
                    alloc_re[i] = 0;
                else
                    alloc_re[i] = 3;

                done = 1;
            end
        end
    end
    else begin //Channel 2 rebalance
        for (integer i = 7; i >= 0; i = i - 1) begin
            if ((alloc_re[i] == 2) && !mask_failed[i] && !done) begin
                if (cap[0] > current_load[0][8] && (total_load[0] < 15)) 
                    alloc_re[i] = 0;
                else if (cap[1] > current_load[1][8] && (total_load[1] < 15)) 
                    alloc_re[i] = 1;
                else
                    alloc_re[i] = 3;

                done = 1;
            end
        end
    end

    for (integer x = 0; x < 8; x = x + 1) begin
        final_alloc[x] = 2'b11;
        if (sorted_idx[0] == x) final_alloc[x] = alloc_re[0];
        else if (sorted_idx[1] == x) final_alloc[x] = alloc_re[1];
        else if (sorted_idx[2] == x) final_alloc[x] = alloc_re[2];
        else if (sorted_idx[3] == x) final_alloc[x] = alloc_re[3];
        else if (sorted_idx[4] == x) final_alloc[x] = alloc_re[4];
        else if (sorted_idx[5] == x) final_alloc[x] = alloc_re[5];
        else if (sorted_idx[6] == x) final_alloc[x] = alloc_re[6];
        else if (sorted_idx[7] == x) final_alloc[x] = alloc_re[7];
    end
end

assign grant_channel = {final_alloc[7], final_alloc[6], final_alloc[5], final_alloc[4],
                       final_alloc[3], final_alloc[2], final_alloc[1], final_alloc[0]};
endmodule


module compare_swap(
    input [25:0] a, b,
    output [25:0] hi, lo
);
    wire signed [6:0] score_a = a[6:0];
    wire signed [6:0] score_b = b[6:0];
    wire [2:0] idx_a = a[25:23];
    wire [2:0] idx_b = b[25:23];

    wire a_wins = (score_a > score_b) || ((score_a == score_b) && (idx_a < idx_b));
    assign hi = a_wins ? a : b;
    assign lo = a_wins ? b : a;
endmodule