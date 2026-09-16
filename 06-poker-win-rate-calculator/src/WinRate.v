//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : WinRate.v
//   	Module Name : WinRate
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`include "Poker.v"

module WinRate (
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_hole_num,
    in_hole_suit,
    in_pub_num,
    in_pub_suit,
    out_valid,
    out_win_rate
);
// ===============================================================
// Input & Output
// ===============================================================
input clk;
input rst_n;
input in_valid;
input [71:0] in_hole_num;
input [35:0] in_hole_suit;
input [11:0] in_pub_num;
input [5:0] in_pub_suit;

output reg out_valid;
output reg [62:0] out_win_rate;

// ===============================================================
// Reg & Wire
// ===============================================================
reg [2:0] state, next_state;
parameter IDLE = 0;
parameter ELIMINATE_1 = 1;
parameter ELIMINATE_2 = 2;
parameter CAL_POKER = 3;
parameter SUM = 4;
parameter SUM_2 = 5;
parameter MULTIPLY = 6;
parameter OUT = 7;

reg [71:0] hole_num;
reg [35:0] hole_suit;
reg [11:0] pub_num;
reg [5:0] pub_suit;

reg next_out_valid;
reg [62:0] next_out_win_rate;

reg [4:0] counter, next_counter;
reg [4:0] num_addr, next_num_addr;

// ===============================================================
// State
// ===============================================================
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end
always@(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if(in_valid)
                next_state = ELIMINATE_1;
        end
        ELIMINATE_1:    next_state = ELIMINATE_2;
        ELIMINATE_2: begin
            if (counter == 15 || num_addr == 31) 
                next_state = CAL_POKER;
        end
        CAL_POKER: begin
            if (num_addr == 29) 
                next_state = SUM;
        end
        SUM:    next_state = SUM_2;
        SUM_2:  next_state = MULTIPLY;
        MULTIPLY: begin
            if (counter == 10)
                next_state = OUT;
        end
        OUT: next_state = IDLE;
    endcase
end


// ===============================================================
// Counter
// ===============================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 0;
    end
    else begin
        counter <= next_counter;
    end
end
always @(*) begin
    next_counter = counter;
    case (state)
        IDLE:   next_counter = 2;
        ELIMINATE_1:
                next_counter = 3;
        ELIMINATE_2: begin
            if (counter == 15 || num_addr == 31)
                next_counter = 2;
            else
                next_counter = counter + 1;
        end
        CAL_POKER: begin
            if (counter == 30)
                next_counter = num_addr + 2;
            else
                next_counter = counter + 1;
        end
        SUM:    next_counter = 0;
        MULTIPLY: begin
            //if (counter == 8)
            //    next_counter = 0;
            //else
                next_counter = counter + 1;
        end
    endcase
end



// ===============================================================
// Input
// ===============================================================
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        hole_num <= 0;
        hole_suit <= 0;
        pub_num <= 0;
        pub_suit <= 0;
    end
    else begin
        if(in_valid) begin
            hole_num <= in_hole_num;
            hole_suit <= in_hole_suit;
            pub_num <= in_pub_num;
            pub_suit <= in_pub_suit;
        end
    end
end


// ===============================================================
// Design
// ===============================================================
//reg [51:0] available_mask, next_available_mask;
reg [3:0] available_mask, next_available_mask;
reg [5:0] remaining_cards [0:30];
reg [5:0] next_remaining_cards [0:30];

//reg [5:0] ava_pointer;
reg [3:0] rem_pointer;
//assign ava_pointer = (counter - 2) << 2;
assign rem_pointer = counter - 1;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (integer i = 0;i < 4;i = i + 1) 
            available_mask[i] <= 0;
    end
    else begin
        for (integer i = 0;i < 4;i = i + 1) 
            available_mask[i] <= next_available_mask[i];
    end
end

always@(*) begin
    next_available_mask = 4'b1111;
    if (state == IDLE) begin
        for (integer i = 0;i < 4;i = i + 1)
            next_available_mask[i] = 1; 
    end
    if(state == ELIMINATE_2 || state == ELIMINATE_1) begin
        if (hole_num[3:0] == counter) begin
            case (hole_suit[1:0])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[7:4] == counter) begin
            case (hole_suit[3:2])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[11:8] == counter) begin
            case (hole_suit[5:4])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[15:12] == counter) begin
            case (hole_suit[7:6])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[19:16] == counter) begin
            case (hole_suit[9:8])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[23:20] == counter) begin
            case (hole_suit[11:10])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[27:24] == counter) begin
            case (hole_suit[13:12])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[31:28] == counter) begin
            case (hole_suit[15:14])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[35:32] == counter) begin
            case (hole_suit[17:16])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[39:36] == counter) begin
            case (hole_suit[19:18])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[43:40] == counter) begin
            case (hole_suit[21:20])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[47:44] == counter) begin
            case (hole_suit[23:22])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[51:48] == counter) begin
            case (hole_suit[25:24])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[55:52] == counter) begin
            case (hole_suit[27:26])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[59:56] == counter) begin
            case (hole_suit[29:28])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[63:60] == counter) begin
            case (hole_suit[31:30])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[67:64] == counter) begin
            case (hole_suit[33:32])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (hole_num[71:68] == counter) begin
            case (hole_suit[35:34])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (pub_num[3:0] == counter) begin
            case (pub_suit[1:0])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (pub_num[7:4] == counter) begin
            case (pub_suit[3:2])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
        if (pub_num[11:8] == counter) begin
            case (pub_suit[5:4])
                2'd0: next_available_mask[0] = 0;
                2'd1: next_available_mask[1] = 0;
                2'd2: next_available_mask[2] = 0;
                2'd3: next_available_mask[3] = 0;
            endcase
        end
    end
end


always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        num_addr <= 0;
        for (integer i = 0;i < 31;i = i + 1) 
            remaining_cards[i] <= 0;
    end
    else begin
        num_addr <= next_num_addr;
        for (integer i = 0;i < 31;i = i + 1) 
            remaining_cards[i] <= next_remaining_cards[i];
    end
end

always @(*) begin
    next_num_addr = num_addr;
    for (integer i = 0;i < 31;i = i + 1) 
            next_remaining_cards[i] = remaining_cards[i];
    case (state)
        IDLE: begin
            next_num_addr = 0;
            for (integer i = 0;i < 31;i = i + 1) 
                next_remaining_cards[i] = 0;
        end
        ELIMINATE_2: begin
            next_num_addr = num_addr + available_mask[0] + available_mask[1] + available_mask[2] + available_mask[3];
            if (available_mask[0]) begin
                next_remaining_cards[num_addr] = {2'b0, rem_pointer};
            end
            if (available_mask[1]) begin
                if (available_mask[0]) 
                    next_remaining_cards[num_addr + 1] = {2'd1, rem_pointer};
                else 
                    next_remaining_cards[num_addr] = {2'd1, rem_pointer};
            end
            if (available_mask[2]) begin
                if (available_mask[0] && available_mask[1])
                    next_remaining_cards[num_addr + 2] = {2'b10, rem_pointer};
                else if (available_mask[0] || available_mask[1])
                    next_remaining_cards[num_addr + 1] = {2'b10, rem_pointer};
                else
                    next_remaining_cards[num_addr] = {2'b10, rem_pointer};
            end
            if (available_mask[3]) begin
                case (available_mask[0] + available_mask[1] + available_mask[2])
                    2'd0: 
                        next_remaining_cards[num_addr] = {2'b11, rem_pointer};
                    2'd1: 
                        next_remaining_cards[num_addr + 1] = {2'b11, rem_pointer};
                    2'd2:
                        next_remaining_cards[num_addr + 2] = {2'b11, rem_pointer};
                    2'd3:
                        next_remaining_cards[num_addr + 3] = {2'b11, rem_pointer};
                endcase
            end
            if (counter == 15 || next_num_addr == 31)
                next_num_addr = 0;
        end
        CAL_POKER: begin
            if (counter == 30) begin
                next_num_addr = num_addr + 1;
            end
        end
    endcase
end

// ===============================================================
// Poker
// ===============================================================
reg [19:0] pub_num_poker, next_pub_num_poker;
reg [9:0] pub_suit_poker, next_pub_suit_poker;
reg [8:0] win, win_poker;

reg [10:0] a_sum[0:8];
reg [10:0] b_sum[0:8];
reg [10:0] next_a_sum[0:8];
reg [10:0] next_b_sum[0:8];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pub_num_poker <= 0;
        pub_suit_poker <= 0;
        win <= 0;
    end
    else begin
        pub_num_poker <= next_pub_num_poker;
        pub_suit_poker <= next_pub_suit_poker;
        if (state == CAL_POKER || state == SUM) 
            win <= win_poker;
    end
end
always @(*) begin
    if (state == CAL_POKER) begin
        next_pub_num_poker = {remaining_cards[num_addr][3:0], remaining_cards[counter][3:0], pub_num};
        next_pub_suit_poker = {remaining_cards[num_addr][5:4], remaining_cards[counter][5:4], pub_suit};
    end
    else if (state == ELIMINATE_2 && (counter == 15 || num_addr == 31)) begin
        next_pub_num_poker = {remaining_cards[0][3:0], remaining_cards[1][3:0], pub_num};
        next_pub_suit_poker = {remaining_cards[0][5:4], remaining_cards[1][5:4], pub_suit};
    end
    else begin
        next_pub_num_poker = 0;
        next_pub_suit_poker = 0;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 9; i = i + 1) begin
            a_sum[i] <= 0;
            b_sum[i] <= 0;
        end
    end
    else begin
        for (integer i = 0; i < 9; i = i + 1) begin
            a_sum[i] <= next_a_sum[i];
            b_sum[i] <= next_b_sum[i];
        end
    end
end
always @(*) begin
    for (integer i = 0; i < 9; i = i + 1) begin
        next_a_sum[i] = a_sum[i];
        next_b_sum[i] = b_sum[i];
    end
    if ((state == CAL_POKER && (counter > 2 || num_addr > 0)) || state == SUM || state == SUM_2) begin
        case (win[0] + win[1] + win[2] + win[3] + win[4] + win[5] + win[6] + win[7] + win[8])
            4'd1: begin
                if (win[0])     next_a_sum[0] = a_sum[0] + 4;
                if (win[1])     next_a_sum[1] = a_sum[1] + 4;
                if (win[2])     next_a_sum[2] = a_sum[2] + 4;
                if (win[3])     next_a_sum[3] = a_sum[3] + 4;
                if (win[4])     next_a_sum[4] = a_sum[4] + 4;
                if (win[5])     next_a_sum[5] = a_sum[5] + 4;
                if (win[6])     next_a_sum[6] = a_sum[6] + 4;
                if (win[7])     next_a_sum[7] = a_sum[7] + 4;
                if (win[8])     next_a_sum[8] = a_sum[8] + 4;
            end
            4'd2: begin
                if (win[0])     next_a_sum[0] = a_sum[0] + 2;
                if (win[1])     next_a_sum[1] = a_sum[1] + 2;
                if (win[2])     next_a_sum[2] = a_sum[2] + 2;
                if (win[3])     next_a_sum[3] = a_sum[3] + 2;
                if (win[4])     next_a_sum[4] = a_sum[4] + 2;
                if (win[5])     next_a_sum[5] = a_sum[5] + 2;
                if (win[6])     next_a_sum[6] = a_sum[6] + 2;
                if (win[7])     next_a_sum[7] = a_sum[7] + 2;
                if (win[8])     next_a_sum[8] = a_sum[8] + 2;
            end
            4'd4: begin
                if (win[0])     next_a_sum[0] = a_sum[0] + 1;
                if (win[1])     next_a_sum[1] = a_sum[1] + 1;
                if (win[2])     next_a_sum[2] = a_sum[2] + 1;
                if (win[3])     next_a_sum[3] = a_sum[3] + 1;
                if (win[4])     next_a_sum[4] = a_sum[4] + 1;
                if (win[5])     next_a_sum[5] = a_sum[5] + 1;
                if (win[6])     next_a_sum[6] = a_sum[6] + 1;
                if (win[7])     next_a_sum[7] = a_sum[7] + 1;
                if (win[8])     next_a_sum[8] = a_sum[8] + 1;
            end
            4'd3: begin
                if (win[0])     next_b_sum[0] = b_sum[0] + 3;
                if (win[1])     next_b_sum[1] = b_sum[1] + 3;
                if (win[2])     next_b_sum[2] = b_sum[2] + 3;
                if (win[3])     next_b_sum[3] = b_sum[3] + 3;
                if (win[4])     next_b_sum[4] = b_sum[4] + 3;
                if (win[5])     next_b_sum[5] = b_sum[5] + 3;
                if (win[6])     next_b_sum[6] = b_sum[6] + 3;
                if (win[7])     next_b_sum[7] = b_sum[7] + 3;
                if (win[8])     next_b_sum[8] = b_sum[8] + 3;
            end
            4'd9: begin
                if (win[0])     next_b_sum[0] = b_sum[0] + 1;
                if (win[1])     next_b_sum[1] = b_sum[1] + 1;
                if (win[2])     next_b_sum[2] = b_sum[2] + 1;
                if (win[3])     next_b_sum[3] = b_sum[3] + 1;
                if (win[4])     next_b_sum[4] = b_sum[4] + 1;
                if (win[5])     next_b_sum[5] = b_sum[5] + 1;
                if (win[6])     next_b_sum[6] = b_sum[6] + 1;
                if (win[7])     next_b_sum[7] = b_sum[7] + 1;
                if (win[8])     next_b_sum[8] = b_sum[8] + 1;
            end
        endcase
    end
    if (state == IDLE) begin
        for (integer i = 0; i < 9; i = i + 1) begin
            next_a_sum[i] = 0;
            next_b_sum[i] = 0;
        end
    end
end

Poker #(.IP_WIDTH(9)) pooo (.IN_HOLE_CARD_NUM(hole_num),
                            .IN_HOLE_CARD_SUIT(hole_suit), 
                            .IN_PUB_CARD_NUM(pub_num_poker),
                            .IN_PUB_CARD_SUIT(pub_suit_poker),
                            .OUT_WINNER(win_poker));


// ===============================================================
// Output
// ===============================================================
reg [17:0] a_mult, b_mult;
reg [17:0] ab_sum, next_ab_sum;
reg [17:0] product, next_product, quo, next_quo;
reg [6:0] out_temp [0:8];
reg [6:0] next_out_temp [0:8];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ab_sum <= 0;
        product <= 0;
        quo <= 0;
        for (integer i = 0;i < 9;i = i + 1) begin
            out_temp[i] <= 0;
        end
        //out_temp <= 0;
    end
    else begin
        ab_sum <= next_ab_sum;
        product <= next_product;
        quo <= next_quo;
        for (integer i = 0;i < 9;i = i + 1) begin
            out_temp[i] <= next_out_temp[i];
        end
        //out_temp <= next_out_temp;
    end
end
always @(*) begin
    a_mult = 0;
    b_mult = 0;
    next_ab_sum = 0;
    next_product = 0;
    next_quo = 0;
    for (integer i = 0;i < 9;i = i + 1) begin
        next_out_temp[i] = out_temp[i];
    end

    case (state)
        IDLE: begin
            for (integer i = 0;i < 9;i = i + 1) begin
                next_out_temp[i] = 0;
            end
        end
        MULTIPLY: begin
            a_mult = a_sum[counter] * 45;
            b_mult = b_sum[counter] * 20;
            next_ab_sum = a_mult + b_mult;

            //next_product = ab_sum * 5;

            next_quo = ab_sum / 837;

            next_out_temp[counter - 2] = quo;
        end 
    endcase
end


always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 0;
        out_win_rate <= 0;
    end
    else begin
        out_valid <= next_out_valid;
        out_win_rate <= next_out_win_rate;
    end
end

always@(*) begin
    next_out_valid = 0;
    next_out_win_rate = 0;
    if(state == OUT) begin
        next_out_valid = 1;
        next_out_win_rate = {out_temp[8], out_temp[7], out_temp[6], out_temp[5], out_temp[4], out_temp[3], out_temp[2], out_temp[1], out_temp[0]};
    end
end 


endmodule