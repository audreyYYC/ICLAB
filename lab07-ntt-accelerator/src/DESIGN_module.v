/**************************************************************************
 * Copyright (c) 2025, OASIS Lab
 * MODULE: CLK_1_MODULE, CLK_2_MODULE, CLK_3_MODULE
 * FILE NAME: DESIGN_module.v
 * VERSRION: 1.0
 * DATE: Oct 29, 2025
 * AUTHOR: Yen-Yu Chen
 * DESCRIPTION: ICLAB2025FALL / LAB7 / DESIGN_module
 * MODIFICATION HISTORY:
 * Date                 Description
 * 
 *************************************************************************/
module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    out_idle,
    out_valid,
    out_data,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             in_valid;
input      [31:0] in_data;
input             out_idle;
output reg        out_valid;
output reg [31:0] out_data;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake;

assign flag_clk1_to_handshake = 0;
//---------------------------------------------------------------------
//   REG & PARAM          
//---------------------------------------------------------------------
reg [3:0] counter, next_counter;
reg [3:0] coefficients [0:127];
reg [1:0] state, next_state;
parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter OUT = 2'd2;
parameter WAIT = 2'd3;

//---------------------------------------------------------------------
//   STATE MACHINE          
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if(in_valid)
                next_state = INPUT;
        end 
        INPUT: begin
            if(counter == 15)
                next_state = OUT;
        end
        OUT: begin
            if(out_idle) begin
                if(counter == 15)
                    next_state = IDLE;
                else
                    next_state = WAIT;
            end
        end
        WAIT: begin
            next_state = OUT;
        end
    endcase
end

//---------------------------------------------------------------------
//   COUNTER         
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter <= 0;
    else
        counter <= next_counter;
end

always @(*) begin
    next_counter = counter;
    case (state)
        IDLE: begin
            if(in_valid)
                next_counter = 1;
            else
                next_counter = 0;
        end 
        INPUT: begin
            if(counter == 15)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
        OUT: begin
            if(out_idle) begin
                if(counter == 15)
                    next_counter = 0;
                else
                    next_counter = counter + 1;
            end
        end
    endcase
end

//---------------------------------------------------------------------
//   DESIGN         
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (integer i = 0; i < 128; i = i + 1) 
            coefficients[i] <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                if(in_valid) begin
                    coefficients[0] <= in_data[3:0];
                    coefficients[1] <= in_data[7:4];
                    coefficients[2] <= in_data[11:8];
                    coefficients[3] <= in_data[15:12];
                    coefficients[4] <= in_data[19:16];
                    coefficients[5] <= in_data[23:20];
                    coefficients[6] <= in_data[27:24];
                    coefficients[7] <= in_data[31:28];
                end
            end
            INPUT: begin
                coefficients[{counter, 3'd0}] <= in_data[3:0];
                coefficients[{counter, 3'd1}] <= in_data[7:4];
                coefficients[{counter, 3'd2}] <= in_data[11:8];
                coefficients[{counter, 3'd3}] <= in_data[15:12];
                coefficients[{counter, 3'd4}] <= in_data[19:16];
                coefficients[{counter, 3'd5}] <= in_data[23:20];
                coefficients[{counter, 3'd6}] <= in_data[27:24];
                coefficients[{counter, 3'd7}] <= in_data[31:28];
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_data <= 0;
        out_valid <= 0;
    end
    else begin
        if(state == OUT && out_idle) begin
            out_valid <= 1;
            out_data <= {coefficients[{counter, 3'd7}],
                        coefficients[{counter, 3'd6}],
                        coefficients[{counter, 3'd5}],
                        coefficients[{counter, 3'd4}],
                        coefficients[{counter, 3'd3}],
                        coefficients[{counter, 3'd2}],
                        coefficients[{counter, 3'd1}],
                        coefficients[{counter, 3'd0}]};
        end
        else begin
            //out_data <= 0;
            out_valid <= 0;
        end
    end
end


endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    fifo_full,
    out_valid,
    out_data,
    busy,
    
    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             in_valid;
input             fifo_full;
input      [31:0] in_data;
output reg        out_valid;
output reg [15:0] out_data;
output reg        busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//---------------------------------------------------------------------
//   REG & PARAM          
//---------------------------------------------------------------------
reg [8:0] counter, next_counter;
reg [1:0] state, next_state;
parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter COMPUTE = 2'd2;
parameter OUT = 2'd3;

reg [15:0] x [0:127];
wire [15:0] twiddle [0:127];

reg [6:0] out_counter, next_out_counter;

//---------------------------------------------------------------------
//   STATE MACHINE          
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if(in_valid)
                next_state = INPUT;
        end 
        INPUT: begin
            if(counter == 15 && in_valid)
                next_state = COMPUTE;
        end
        COMPUTE: begin
            if(counter == 447) // 64 * 7 = 447
                next_state = OUT;
        end
        OUT: begin
            if(out_counter == 127 && out_valid)
                next_state = IDLE;
        end
    endcase
end

//---------------------------------------------------------------------
//   COUNTER         
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter <= 0;
    else
        counter <= next_counter;
end

always @(*) begin
    next_counter = counter;
    case (state)
        IDLE: begin
            if(in_valid)
                next_counter = 1;
            else
                next_counter = 0;
        end 
        INPUT: begin
            if (in_valid) begin
                if(counter == 15)
                    next_counter = 0;
                else
                    next_counter = counter + 1;
            end
        end
        COMPUTE: begin
            if(counter == 447)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        out_counter <= 0;
    else
        out_counter <= next_out_counter;
end

always @(*) begin
    next_out_counter = out_counter;
    case (state)
        COMPUTE: begin
            if(counter > 385) begin
                if(out_valid) 
                    next_out_counter = out_counter + 1;
            end
            else
                next_out_counter = 0;
        end
        OUT: begin
            if(out_valid) begin
                next_out_counter = out_counter + 1;
            end
        end
        default: next_out_counter = 0;
    endcase
    
end

//---------------------------------------------------------------------
//   NTT         
//---------------------------------------------------------------------
reg [6:0] j_addr, jht_addr;
reg [2:0] ht_bits;
reg [6:0] twiddle_idx;
reg [6:0] temp;
reg [29:0] temp_x, temp_z, temp_zz;
reg [15:0] temp_xx, temp_yy;
reg [16:0] mont_result, mont_ht;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ht_bits <= 6;
    end
    else begin
        if (state == COMPUTE) begin
            if (counter[5:0] == 63) 
                ht_bits <= ht_bits - 1;
        end
        else
            ht_bits <= 6;
    end
end

always @(*) begin
    case (ht_bits)
        3'd6: begin   
            temp = counter;
            twiddle_idx = 1;
        end
        3'd5: begin   
            temp = {counter[5], 1'b0, counter[4:0]};
            twiddle_idx = {1'b1, counter[5]};
        end
        3'd4: begin   
            temp = {counter[5:4], 1'b0, counter[3:0]};
            twiddle_idx = {1'b1, counter[5:4]};
        end
        3'd3: begin   
            temp = {counter[5:3], 1'b0, counter[2:0]};
            twiddle_idx = {1'b1, counter[5:3]};
        end
        3'd2: begin   
            temp = {counter[5:2], 1'b0, counter[1:0]};
            twiddle_idx = {1'b1, counter[5:2]};
        end
        3'd1: begin   
            temp = {counter[5:1], 1'b0, counter[0]};
            twiddle_idx = {1'b1, counter[5:1]};
        end
        default: begin
            temp = {counter[5:0], 1'b0};
            twiddle_idx = {1'b1, counter[5:0]};
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        j_addr <= 0;
        jht_addr <= 0;
        temp_x <= 0;
    end
    else begin
        if (state == COMPUTE) begin
            j_addr <= temp;
            jht_addr <= temp + (1 << ht_bits);
            temp_x <= x[temp + (1 << ht_bits)] * twiddle[twiddle_idx];
        end
        else begin
            j_addr <= 0;
            jht_addr <= 0;
            temp_x <= 0;
        end
    end
end

always @(*) begin
    temp_xx = temp_x[15:0];
    temp_yy = (temp_xx * 12287);
    temp_z = (temp_x + temp_yy * 12289) >> 16;
    
    if (temp_z >= 12289) begin
        if(x[j_addr] + 12289 >= temp_z)
            mont_ht = x[j_addr] - temp_z + 12289;
        else
            mont_ht = x[j_addr] - temp_z + 24578;

        if(temp_z + x[j_addr] >= 24578)
            mont_result = temp_z + x[j_addr] - 24578;
        else
            mont_result = temp_z + x[j_addr] - 12289;
    end
    else begin
        if(x[j_addr] >= temp_z)
            mont_ht = x[j_addr] - temp_z;
        else
            mont_ht = x[j_addr] - temp_z + 12289;

        if(temp_z + x[j_addr] >= 12289)
            mont_result = temp_z + x[j_addr] - 12289;
        else
            mont_result = temp_z + x[j_addr];
    end
end

//---------------------------------------------------------------------
//   X0 ~ X127        
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < 128; i = i + 1) 
            x[i] <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                if(in_valid) begin
                    x[0] <= {10'b0, in_data[3:0]};
                    x[1] <= {10'b0, in_data[7:4]};
                    x[2] <= {10'b0, in_data[11:8]};
                    x[3] <= {10'b0, in_data[15:12]};
                    x[4] <= {10'b0, in_data[19:16]};
                    x[5] <= {10'b0, in_data[23:20]};
                    x[6] <= {10'b0, in_data[27:24]};
                    x[7] <= {10'b0, in_data[31:28]};
                end
            end 
            INPUT: begin
                if(in_valid) begin
                    x[{counter[3:0], 3'd0}] <= {10'b0, in_data[3:0]};
                    x[{counter[3:0], 3'd1}] <= {10'b0, in_data[7:4]};
                    x[{counter[3:0], 3'd2}] <= {10'b0, in_data[11:8]};
                    x[{counter[3:0], 3'd3}] <= {10'b0, in_data[15:12]};
                    x[{counter[3:0], 3'd4}] <= {10'b0, in_data[19:16]};
                    x[{counter[3:0], 3'd5}] <= {10'b0, in_data[23:20]};
                    x[{counter[3:0], 3'd6}] <= {10'b0, in_data[27:24]};
                    x[{counter[3:0], 3'd7}] <= {10'b0, in_data[31:28]};
                end
            end
            COMPUTE: begin
                if(counter !== 0) begin
                    x[j_addr] <= mont_result;
                    x[jht_addr] <= mont_ht;
                end
            end
            OUT: begin
                if(j_addr == 126) begin
                    x[j_addr] <= mont_result;
                    x[jht_addr] <= mont_ht;
                end
            end
        endcase
    end
end

//---------------------------------------------------------------------
//   OUTPUT DATA         
//---------------------------------------------------------------------
always @(*) begin
    out_data = 0;
    out_valid = 0;
    if((state == OUT || counter > 385) && !flag_fifo_to_clk2 && !fifo_full) begin
        out_valid = 1;
        out_data = x[out_counter];
    end
end

//---------------------------------------------------------------------
//   BUSY
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        busy <= 0;
    else begin
        case (state)
            IDLE, INPUT: begin
                busy <= 0;
            end
            COMPUTE: begin
                busy <= 1;
            end
            OUT: begin
                busy <= 1;
            end
        endcase
    end
end

//---------------------------------------------------------------------
//   GMB TWIDDLE         
//---------------------------------------------------------------------
assign twiddle[0] = 14'd4091;    assign twiddle[1] = 14'd7888;    assign twiddle[2] = 14'd11060;   assign twiddle[3] = 14'd11208;
assign twiddle[4] = 14'd6960;    assign twiddle[5] = 14'd4342;    assign twiddle[6] = 14'd6275;    assign twiddle[7] = 14'd9759;
assign twiddle[8] = 14'd1591;    assign twiddle[9] = 14'd6399;    assign twiddle[10] = 14'd9477;   assign twiddle[11] = 14'd5266;
assign twiddle[12] = 14'd586;    assign twiddle[13] = 14'd5825;   assign twiddle[14] = 14'd7538;   assign twiddle[15] = 14'd9710;
assign twiddle[16] = 14'd1134;   assign twiddle[17] = 14'd6407;   assign twiddle[18] = 14'd1711;   assign twiddle[19] = 14'd965;
assign twiddle[20] = 14'd7099;   assign twiddle[21] = 14'd7674;   assign twiddle[22] = 14'd3743;   assign twiddle[23] = 14'd6442;
assign twiddle[24] = 14'd10414;  assign twiddle[25] = 14'd8100;   assign twiddle[26] = 14'd1885;   assign twiddle[27] = 14'd1688;
assign twiddle[28] = 14'd1364;   assign twiddle[29] = 14'd10329;  assign twiddle[30] = 14'd10164;  assign twiddle[31] = 14'd9180;
assign twiddle[32] = 14'd12210;  assign twiddle[33] = 14'd6240;   assign twiddle[34] = 14'd997;    assign twiddle[35] = 14'd117;
assign twiddle[36] = 14'd4783;   assign twiddle[37] = 14'd4407;   assign twiddle[38] = 14'd1549;   assign twiddle[39] = 14'd7072;
assign twiddle[40] = 14'd2829;   assign twiddle[41] = 14'd6458;   assign twiddle[42] = 14'd4431;   assign twiddle[43] = 14'd8877;
assign twiddle[44] = 14'd7144;   assign twiddle[45] = 14'd2564;   assign twiddle[46] = 14'd5664;   assign twiddle[47] = 14'd4042;
assign twiddle[48] = 14'd12189;  assign twiddle[49] = 14'd432;    assign twiddle[50] = 14'd10751;  assign twiddle[51] = 14'd1237;
assign twiddle[52] = 14'd7610;   assign twiddle[53] = 14'd1534;   assign twiddle[54] = 14'd3983;   assign twiddle[55] = 14'd7863;
assign twiddle[56] = 14'd2181;   assign twiddle[57] = 14'd6308;   assign twiddle[58] = 14'd8720;   assign twiddle[59] = 14'd6570;
assign twiddle[60] = 14'd4843;   assign twiddle[61] = 14'd1690;   assign twiddle[62] = 14'd14;     assign twiddle[63] = 14'd3872;
assign twiddle[64] = 14'd5569;   assign twiddle[65] = 14'd9368;   assign twiddle[66] = 14'd12163;  assign twiddle[67] = 14'd2019;
assign twiddle[68] = 14'd7543;   assign twiddle[69] = 14'd2315;   assign twiddle[70] = 14'd4673;   assign twiddle[71] = 14'd7340;
assign twiddle[72] = 14'd1553;   assign twiddle[73] = 14'd1156;   assign twiddle[74] = 14'd8401;   assign twiddle[75] = 14'd11389;
assign twiddle[76] = 14'd1020;   assign twiddle[77] = 14'd2967;   assign twiddle[78] = 14'd10772;  assign twiddle[79] = 14'd7045;
assign twiddle[80] = 14'd3316;   assign twiddle[81] = 14'd11236;  assign twiddle[82] = 14'd5285;   assign twiddle[83] = 14'd11578;
assign twiddle[84] = 14'd10637;  assign twiddle[85] = 14'd10086;  assign twiddle[86] = 14'd9493;   assign twiddle[87] = 14'd6180;
assign twiddle[88] = 14'd9277;   assign twiddle[89] = 14'd6130;   assign twiddle[90] = 14'd3323;   assign twiddle[91] = 14'd883;
assign twiddle[92] = 14'd10469;  assign twiddle[93] = 14'd489;    assign twiddle[94] = 14'd1502;   assign twiddle[95] = 14'd2851;
assign twiddle[96] = 14'd11061;  assign twiddle[97] = 14'd9729;   assign twiddle[98] = 14'd2742;   assign twiddle[99] = 14'd12241;
assign twiddle[100] = 14'd4970;  assign twiddle[101] = 14'd10481; assign twiddle[102] = 14'd10078; assign twiddle[103] = 14'd1195;
assign twiddle[104] = 14'd730;   assign twiddle[105] = 14'd1762;  assign twiddle[106] = 14'd3854;  assign twiddle[107] = 14'd2030;
assign twiddle[108] = 14'd5892;  assign twiddle[109] = 14'd10922; assign twiddle[110] = 14'd9020;  assign twiddle[111] = 14'd5274;
assign twiddle[112] = 14'd9179;  assign twiddle[113] = 14'd3604;  assign twiddle[114] = 14'd3782;  assign twiddle[115] = 14'd10206;
assign twiddle[116] = 14'd3180;  assign twiddle[117] = 14'd3467;  assign twiddle[118] = 14'd4668;  assign twiddle[119] = 14'd2446;
assign twiddle[120] = 14'd7613;  assign twiddle[121] = 14'd9386;  assign twiddle[122] = 14'd834;   assign twiddle[123] = 14'd7703;
assign twiddle[124] = 14'd6836;  assign twiddle[125] = 14'd3403;  assign twiddle[126] = 14'd5351;  assign twiddle[127] = 14'd12276;

endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             fifo_empty;
input      [15:0] fifo_rdata;
output reg        fifo_rinc;
output reg        out_valid;
output reg [15:0] out_data;

// You can change the input / output of the custom flag ports
input  flag_fifo_to_clk3;
output flag_clk3_to_fifo;


//---------------------------------------------------------------------
//   REG & PARAM          
//---------------------------------------------------------------------
reg [6:0] counter, next_counter;
reg [1:0] state, next_state;
parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter OUT = 2'd2;

//---------------------------------------------------------------------
//   STATE MACHINE          
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE, INPUT: begin
            if(!fifo_empty)
                next_state = OUT;
        end 
        OUT: begin
            if(counter == 127)
                next_state = IDLE;
            else if(fifo_empty)
                next_state = INPUT;
        end
    endcase
end

//---------------------------------------------------------------------
//   COUNTER         
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        counter <= 0;
    else
        counter <= next_counter;
end

always @(*) begin
    next_counter = counter;
    case (state)
        IDLE: 
            next_counter = 0;
        OUT: begin
            if (counter == 127)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
    endcase
end

//---------------------------------------------------------------------
//   DESIGN         
//---------------------------------------------------------------------
always @(*) begin
    if(!fifo_empty)
        fifo_rinc = 1;
    else
        fifo_rinc = 0;
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_data <= 0;
        out_valid <= 0;
    end
    else begin
        if (state == OUT) begin
            out_data <= fifo_rdata;
            out_valid <= 1;
        end
        else begin
            out_data <= 0;
            out_valid <= 0;
        end
    end
end

endmodule