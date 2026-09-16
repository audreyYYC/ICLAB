module HLPTE(
    // input signals
    clk,
    rst_n,
    in_valid_data,
    in_valid_param,
    
    data,
	index,
	mode,
    QP,
	
    // output signals
    out_valid,
    out_value
);

input                     clk;
input                     rst_n;
input                     in_valid_data;
input                     in_valid_param;

input              [7:0]  data;
input              [3:0]  index;
input                     mode;
input              [4:0]  QP;

output reg                out_valid;
output reg signed [31:0]  out_value;


//==================================================================
// parameter & integer
//==================================================================
//state
parameter IDLE = 5'd0;
parameter INPUT_DATA = 5'd1;
parameter IDLE_PARAM = 5'd2;
parameter INPUT_PARAM1 = 5'd3;
parameter INPUT_PARAM2 = 5'd4;
parameter INPUT_PARAM3 = 5'd5;
parameter INTRA_16 = 5'd6;
parameter INTRA_4 = 5'd7;
parameter RESIDUAL = 5'd8;
parameter INTEGER_TRANSFORM = 5'd9;
parameter QUANTIZATION_1 = 5'd10;
parameter QUANTIZATION_2 = 5'd11;
parameter OUTPUT = 5'd12;

parameter RECONSTRUCTION_L = 5'd13;
parameter RECONSTRUCTION_T = 5'd14;
parameter RECONSTRUCTION_T_L = 5'd15;
parameter RECONSTRUCTION_0 = 5'd16;

//intra_state
parameter INTRA_IDLE = 3'd0;
parameter GET_DATA_4 = 3'd1;
parameter DC_4_0 = 3'd2;
parameter DC_4 = 3'd3;
parameter DC_16_0 = 3'd4;
parameter SAD_16 = 3'd5;


//==================================================================
// reg & wire
//==================================================================
//SRAM
reg [11:0] sram_addr;
reg [3:0] frame_idx, next_frame_idx;
reg [5:0] block_idx, next_block_idx;
reg [5:0] last_block_idx, next_last_block_idx;
reg [1:0] row_idx, next_row_idx;
reg [5:0] sad16_block_idx, next_sad16_block_idx;
reg [31:0] sram_din;
wire [31:0] sram_dout;
reg WEB; // 0: write, 1: read
reg CS;
reg OE; 

reg [9:0] input_counter, next_input_counter;
reg [7:0] data0, data1, data2, data3;

//state
reg [4:0] state, next_state;
reg [3:0] intra_state, next_intra_state;
reg [6:0] counter, next_counter, last_counter;
reg [3:0] frame_counter, next_frame_counter;

// param
reg [3:0] frame;
reg cur_mode [0:3];
reg [4:0] cur_qp;

//intra
reg [7:0] data_4 [0:3][0:3];
reg [1:0] cur_sec, next_cur_sec;
reg ver_available, hor_available;

//output
reg next_out_valid;
reg signed [31:0] next_out_value;

//==================================================================
// SRAM
//==================================================================
MEM sram_inst(

    .A0(sram_addr[0]),   .A1(sram_addr[1]),   .A2(sram_addr[2]),   .A3(sram_addr[3]),
    .A4(sram_addr[4]),   .A5(sram_addr[5]),   .A6(sram_addr[6]),   .A7(sram_addr[7]),
    .A8(sram_addr[8]),   .A9(sram_addr[9]),   .A10(sram_addr[10]), .A11(sram_addr[11]),
    
    .DO0(sram_dout[0]),   .DO1(sram_dout[1]),   .DO2(sram_dout[2]),   .DO3(sram_dout[3]),
    .DO4(sram_dout[4]),   .DO5(sram_dout[5]),   .DO6(sram_dout[6]),   .DO7(sram_dout[7]),
    .DO8(sram_dout[8]),   .DO9(sram_dout[9]),   .DO10(sram_dout[10]), .DO11(sram_dout[11]),
    .DO12(sram_dout[12]), .DO13(sram_dout[13]), .DO14(sram_dout[14]), .DO15(sram_dout[15]),
    .DO16(sram_dout[16]), .DO17(sram_dout[17]), .DO18(sram_dout[18]), .DO19(sram_dout[19]),
    .DO20(sram_dout[20]), .DO21(sram_dout[21]), .DO22(sram_dout[22]), .DO23(sram_dout[23]),
    .DO24(sram_dout[24]), .DO25(sram_dout[25]), .DO26(sram_dout[26]), .DO27(sram_dout[27]),
    .DO28(sram_dout[28]), .DO29(sram_dout[29]), .DO30(sram_dout[30]), .DO31(sram_dout[31]),
    
    .DI0(sram_din[0]),   .DI1(sram_din[1]),   .DI2(sram_din[2]),   .DI3(sram_din[3]),
    .DI4(sram_din[4]),   .DI5(sram_din[5]),   .DI6(sram_din[6]),   .DI7(sram_din[7]),
    .DI8(sram_din[8]),   .DI9(sram_din[9]),   .DI10(sram_din[10]), .DI11(sram_din[11]),
    .DI12(sram_din[12]), .DI13(sram_din[13]), .DI14(sram_din[14]), .DI15(sram_din[15]),
    .DI16(sram_din[16]), .DI17(sram_din[17]), .DI18(sram_din[18]), .DI19(sram_din[19]),
    .DI20(sram_din[20]), .DI21(sram_din[21]), .DI22(sram_din[22]), .DI23(sram_din[23]),
    .DI24(sram_din[24]), .DI25(sram_din[25]), .DI26(sram_din[26]), .DI27(sram_din[27]),
    .DI28(sram_din[28]), .DI29(sram_din[29]), .DI30(sram_din[30]), .DI31(sram_din[31]),
    
    .CK(clk),
    .WEB(WEB),
    .OE(OE),
    .CS(CS)


);

//counter 0~1024
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_counter <= 0;
    end
    else 
        input_counter <= next_input_counter;
end
always @(*) begin
    if (state == INPUT_DATA) 
        next_input_counter = input_counter + 1;
    else if (state == IDLE && in_valid_data) 
        next_input_counter = 1;
    else
        next_input_counter = 0;
end

//frame 0~16
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_idx <= 0;
    end
    else
        frame_idx <= next_frame_idx;
end
always @(*) begin
    next_frame_idx = frame_idx;
    case (state)
        IDLE:
            next_frame_idx = 0; 
        INPUT_DATA: begin
            if (input_counter == 1023)
                next_frame_idx = frame_idx + 1;
        end
        INPUT_PARAM1:
            next_frame_idx = frame;
    endcase
end

//block 0~64
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        block_idx <= 0;
        //last_block_idx <= 0;
    end
    else begin
        block_idx <= next_block_idx;
        last_block_idx <= next_last_block_idx;
    end
end
always @(*) begin
    next_block_idx = block_idx;
    next_last_block_idx = last_block_idx;
    case (state)
        IDLE: 
            next_block_idx = 0;
        INPUT_DATA: begin
            if (input_counter[1:0] == 3) begin
                if (block_idx[2:0] == 7) begin
                    if (row_idx == 3) 
                        next_block_idx = block_idx + 1;
                    else
                        next_block_idx = {block_idx[5:3], 3'b0};
                end
                else
                    next_block_idx = block_idx + 1;
            end
        end
        IDLE_PARAM:
            next_block_idx = 0;
        OUTPUT: begin
            if (counter == 13) begin
                case (block_idx)
                    6'd27: next_block_idx = 4;
                    6'd59: next_block_idx = 36;
                    6'd3, 6'd11, 6'd19, 6'd7, 6'd15, 6'd23, 6'd35, 6'd43, 6'd51, 6'd39, 6'd47, 6'd55:
                        next_block_idx = block_idx + 5;
                    default: next_block_idx = block_idx + 1;
                endcase
                next_last_block_idx = block_idx;
            end
        end
    endcase
end

//row 0~3
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_idx <= 0;
    end
    else 
        row_idx <= next_row_idx;
end
always @(*) begin
    next_row_idx = row_idx;
    case (intra_state)
        DC_16_0: 
            next_row_idx = 3;

        GET_DATA_4, SAD_16:
            next_row_idx = row_idx + 1;
    endcase

    case (state)
        RESIDUAL: 
            next_row_idx = row_idx + 1;
        OUTPUT: begin
            case (counter)
                4'd13:   next_row_idx = 0; 
                4'd14:   next_row_idx = 1;
                4'd15:   next_row_idx = 2;
            endcase
        end
        INTRA_16: begin
            case (counter)
                7'd64:   next_row_idx = 0; 
                7'd65:   next_row_idx = 1;
                7'd66:   next_row_idx = 2;
            endcase
        end
        INTRA_4: begin
            case (counter)
                2'd1:   next_row_idx = 0; 
                2'd2:   next_row_idx = 1;
                2'd3:   next_row_idx = 2;
            endcase
        end
        INPUT_DATA: begin
            if (input_counter[1:0] == 3 && block_idx[2:0] == 7) 
                next_row_idx = row_idx + 1;
        end
        INPUT_PARAM2:
            next_row_idx = 1;
        INPUT_PARAM3:
            next_row_idx = 2;
        RECONSTRUCTION_L, RECONSTRUCTION_T, RECONSTRUCTION_T_L, RECONSTRUCTION_0: begin
            case (counter)
                2'd1:   next_row_idx = 0; 
                2'd2:   next_row_idx = 1;
                2'd3:   next_row_idx = 2;
            endcase
        end
        IDLE_PARAM, IDLE:
            next_row_idx = 0;
    endcase
end


assign CS = 1;
assign OE = 1;
//WEB
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        WEB <= 1;
    else begin
        if (state == INPUT_DATA && input_counter[1:0] == 3) 
            WEB <= 0;
        else
            WEB <= 1;
    end
end

//SRAM DIN
assign sram_din = {data0, data1, data2, data3};
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        /*data0 <= 0;
        data1 <= 0;
        data2 <= 0;
        data3 <= 0;*/
    end
    else if (in_valid_data) begin
        case (input_counter[1:0])
            2'd0:   data0 <= data;
            2'd1:   data1 <= data;
            2'd2:   data2 <= data;
            2'd3:   data3 <= data;            
            default: begin
            end
        endcase
    end
end

//SRAM addr
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sram_addr <= 0;
    end
    else if (intra_state == SAD_16 && counter < 65)
        sram_addr <= {frame_idx, sad16_block_idx, row_idx};
    else
        sram_addr <= {frame_idx, block_idx, row_idx};
end

//input param
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame <= 0;
        cur_mode[0] <= 0;
        cur_mode[1] <= 0;
        cur_mode[2] <= 0;
        cur_mode[3] <= 0;
        cur_qp <= 0;
    end
    else begin
    case (state)
        IDLE_PARAM: begin
            if (in_valid_param) begin
                frame <= index;
                cur_qp <= QP;
                cur_mode[0] <= mode;
            end
        end
        INPUT_PARAM1: cur_mode[1] <= mode;
        INPUT_PARAM2: cur_mode[2] <= mode;
        INPUT_PARAM3: cur_mode[3] <= mode;
        default: begin end
    endcase
    end
end

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
    next_state = state;
    case (state)
        IDLE: begin
            if (in_valid_data)
                next_state = INPUT_DATA;
            else
                next_state = IDLE;
        end
        INPUT_DATA: begin
            if(!in_valid_data)
                next_state = IDLE_PARAM;
            else
                next_state = INPUT_DATA;
        end
        IDLE_PARAM: begin
            if(in_valid_param)
                next_state = INPUT_PARAM1;
            else
                next_state = IDLE_PARAM;
        end
        INPUT_PARAM1:
            next_state = INPUT_PARAM2;
        INPUT_PARAM2:
            next_state = INPUT_PARAM3;
        INPUT_PARAM3: begin
            if (cur_mode[0] == 0)
                next_state = RESIDUAL;
            else
                next_state = INTRA_4;
        end
        INTRA_4: begin
            if (intra_state == DC_4 && counter == 3)
                next_state = RESIDUAL;
            else
                next_state = INTRA_4;
        end
        INTRA_16: begin
            if (intra_state == SAD_16 && counter == 66)
                next_state = RESIDUAL;
            else
                next_state = INTRA_16;
        end
        RESIDUAL: begin
            if (counter == 4)
                next_state = INTEGER_TRANSFORM;
            else
                next_state = RESIDUAL;
        end
        INTEGER_TRANSFORM: next_state = QUANTIZATION_1;
        QUANTIZATION_1: next_state = QUANTIZATION_2;
        QUANTIZATION_2: next_state = OUTPUT;

        OUTPUT: begin
            if (counter == 15) begin
                if (last_block_idx == 63)
                    if (frame_counter == 0)
                        next_state = IDLE;
                    else
                        next_state = IDLE_PARAM;

                else if (cur_mode[cur_sec])  //4*4
                    next_state = RECONSTRUCTION_0;
                
                else begin //16*16
                    case (block_idx)
                        //6'd3, 6'd11, 6'd19, 6'd35, 6'd43, 6'd51, 6'd59: 
                        6'd8, 6'd16, 6'd24, 6'd40, 6'd48, 6'd56, 6'd36: 
                            next_state = RECONSTRUCTION_L;
                        //6'd24, 6'd25, 6'd26, 6'd28, 6'd29, 6'd30, 6'd31:
                        6'd25, 6'd26, 6'd27, 6'd29, 6'd30, 6'd31, 6'd32:
                            next_state = RECONSTRUCTION_T;
                        //6'd27:
                        6'd4:
                            next_state = RECONSTRUCTION_T_L;
                        default:
                            next_state = RESIDUAL;
                    endcase
                end 
            end
        end
        RECONSTRUCTION_L, RECONSTRUCTION_T, RECONSTRUCTION_T_L: begin
            if (counter == 3) begin
                if (block_idx == 4 || block_idx == 32 || block_idx == 36) begin // 27 31 59
                    if (cur_mode[cur_sec + 1])
                        next_state = INTRA_4;
                    else
                        next_state = INTRA_16;
                end
                else
                    next_state = RESIDUAL;
            end
        end
        RECONSTRUCTION_0: begin
            if (counter == 3) begin
                if (block_idx == 4 || block_idx == 32 || block_idx == 36) begin // 27 31 59
                    if (cur_mode[cur_sec + 1])
                        next_state = INTRA_4;
                    else
                        next_state = INTRA_16;
                end
                else
                    next_state = INTRA_4;
            end
        end
            
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        intra_state <= INTRA_IDLE;
    else
        intra_state <= next_intra_state;
end

always @(*) begin
    next_intra_state = intra_state;
    case (intra_state)
        INTRA_IDLE: begin
            case (state)
                INPUT_PARAM3: begin
                    if (cur_mode[0]) 
                        next_intra_state = GET_DATA_4;
                end
                RECONSTRUCTION_L, RECONSTRUCTION_T, RECONSTRUCTION_T_L: begin
                    if (counter == 3) begin
                        if (block_idx == 4 || block_idx == 32 || block_idx == 36) begin // 27 31 59
                            if (cur_mode[cur_sec + 1])
                                next_intra_state = GET_DATA_4;
                            else
                                next_intra_state = DC_16_0;
                        end
                    end
                end
                RECONSTRUCTION_0: begin
                    if (counter == 3) begin
                        if (block_idx == 4 || block_idx == 32 || block_idx == 36) begin // 27 31 59
                            if (cur_mode[cur_sec + 1])
                                next_intra_state = GET_DATA_4;
                            else
                                next_intra_state = DC_16_0;
                        end
                        else
                            next_intra_state = GET_DATA_4;
                    end
                end
            endcase
        end
        GET_DATA_4: begin
            if (counter == 3) 
                next_intra_state = DC_4_0;
            else
                next_intra_state = GET_DATA_4;
        end
        DC_4_0: next_intra_state = DC_4;
        DC_4: begin
            if (counter == 3)
                next_intra_state = INTRA_IDLE;
            else
                next_intra_state = DC_4;
        end
        DC_16_0: next_intra_state = SAD_16;
        SAD_16: begin
            if (counter == 66)
                next_intra_state = INTRA_IDLE;
            else
                next_intra_state = SAD_16;
        end
    endcase
end


//==================================================================
// counter
//==================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <= 0;
        //last_counter <= 0;
    end
    else begin
        counter <= next_counter;
        last_counter <= counter;
    end
end
always @(*) begin
    next_counter = counter;
    case (intra_state)
        INTRA_IDLE: begin
            if (state == OUTPUT && counter == 15)
                next_counter = 0;
        end
        GET_DATA_4: begin
            if (counter == 3)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
        DC_4: begin
            if (counter == 3)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
        DC_16_0: next_counter = 1;
        SAD_16: begin
            if (counter == 66)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
    endcase
    case (state)
        INPUT_PARAM3: begin
            //if(!cur_mode[0])
                next_counter = 0;
        end
        RESIDUAL: begin
            if (counter == 4)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
        OUTPUT: begin
            if (counter == 15)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
        RECONSTRUCTION_L, RECONSTRUCTION_T, RECONSTRUCTION_T_L, RECONSTRUCTION_0: begin
            if (counter == 3)
                next_counter = 0;
            else
                next_counter = counter + 1;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        //cur_sec <= 0;
    end
    else begin
        cur_sec <= next_cur_sec;
    end
end
always @(*) begin
    next_cur_sec = cur_sec;
    if (state == IDLE_PARAM) begin
        next_cur_sec = 0; 
    end
    else if (block_idx == 4 || block_idx == 32 || block_idx == 36) begin // 27 31 59
        if ((state == RECONSTRUCTION_L || state == RECONSTRUCTION_T || state == RECONSTRUCTION_T_L || state == RECONSTRUCTION_0) && counter == 3) 
            next_cur_sec = cur_sec + 1;
    end
end

//sad16 block idx
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sad16_block_idx <= 0;
    end
    else begin
        sad16_block_idx <= next_sad16_block_idx;
    end
end
always @(*) begin
    next_sad16_block_idx = sad16_block_idx;
    if (state == INPUT_PARAM2 && !cur_mode[0])
        next_sad16_block_idx = 0;
    else if(state == OUTPUT && counter == 13) begin
        if (block_idx == 27 && !cur_mode[1])
            next_sad16_block_idx = 4;
        else if (block_idx == 31 && !cur_mode[2])
            next_sad16_block_idx = 32;
        else if (block_idx == 59 && !cur_mode[3])
            next_sad16_block_idx = 36;
    end
    else if (intra_state == SAD_16 && counter[1:0] == 1) begin
        case (sad16_block_idx)
            //6'd3, 6'd11, 6'd19, 
            6'd7, 6'd15, 6'd23, 6'd35, 6'd43, 6'd51, 6'd39, 6'd47, 6'd55:
                next_sad16_block_idx = sad16_block_idx + 5;
            default: next_sad16_block_idx = sad16_block_idx + 1;
        endcase
    end
end

//frame_idx
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_counter <= 0;
    end
    else begin
        frame_counter <= next_frame_counter;
    end
end
always @(*) begin
    next_frame_counter = frame_counter;
    if (state == IDLE) begin
        next_frame_counter = 0;
    end
    else if (state == INPUT_PARAM1)
        next_frame_counter = frame_counter + 1;
end


//==================================================================
// INTRA PREDICTION
//==================================================================
//get 4*4 data
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        /*data_4[0][0] <= 0;
        data_4[0][1] <= 0;
        data_4[0][2] <= 0;
        data_4[0][3] <= 0;
        data_4[1][0] <= 0;
        data_4[1][1] <= 0;
        data_4[1][2] <= 0;
        data_4[1][3] <= 0;
        data_4[2][0] <= 0;
        data_4[2][1] <= 0;
        data_4[2][2] <= 0;
        data_4[2][3] <= 0;
        data_4[3][0] <= 0;
        data_4[3][1] <= 0;
        data_4[3][2] <= 0;
        data_4[3][3] <= 0;*/
    end
    else begin
        if (intra_state == GET_DATA_4) begin
            case (counter)
                2'd0: begin
                    data_4[0][0] <= sram_dout[31:24];
                    data_4[0][1] <= sram_dout[23:16];
                    data_4[0][2] <= sram_dout[15:8];
                    data_4[0][3] <= sram_dout[7:0];
                end  
                2'd1: begin
                    data_4[1][0] <= sram_dout[31:24];
                    data_4[1][1] <= sram_dout[23:16];
                    data_4[1][2] <= sram_dout[15:8];
                    data_4[1][3] <= sram_dout[7:0];
                end  
                2'd2: begin
                    data_4[2][0] <= sram_dout[31:24];
                    data_4[2][1] <= sram_dout[23:16];
                    data_4[2][2] <= sram_dout[15:8];
                    data_4[2][3] <= sram_dout[7:0];
                end  
                2'd3: begin
                    data_4[3][0] <= sram_dout[31:24];
                    data_4[3][1] <= sram_dout[23:16];
                    data_4[3][2] <= sram_dout[15:8];
                    data_4[3][3] <= sram_dout[7:0];
                end  
            endcase
        end
        else if (intra_state == SAD_16 || intra_state == DC_16_0) begin
            case (counter[1:0])
                2'd0: begin
                    data_4[0][0] <= sram_dout[31:24];
                    data_4[0][1] <= sram_dout[23:16];
                    data_4[0][2] <= sram_dout[15:8];
                    data_4[0][3] <= sram_dout[7:0];
                end  
                2'd1: begin
                    data_4[1][0] <= sram_dout[31:24];
                    data_4[1][1] <= sram_dout[23:16];
                    data_4[1][2] <= sram_dout[15:8];
                    data_4[1][3] <= sram_dout[7:0];
                end  
                2'd2: begin
                    data_4[2][0] <= sram_dout[31:24];
                    data_4[2][1] <= sram_dout[23:16];
                    data_4[2][2] <= sram_dout[15:8];
                    data_4[2][3] <= sram_dout[7:0];
                end  
                2'd3: begin
                    data_4[3][0] <= sram_dout[31:24];
                    data_4[3][1] <= sram_dout[23:16];
                    data_4[3][2] <= sram_dout[15:8];
                    data_4[3][3] <= sram_dout[7:0];
                end  
            endcase
        end
        else if (state == RESIDUAL) begin
            case (counter)
                2'd0: begin
                    data_4[0][0] <= sram_dout[31:24];
                    data_4[0][1] <= sram_dout[23:16];
                    data_4[0][2] <= sram_dout[15:8];
                    data_4[0][3] <= sram_dout[7:0];
                end  
                2'd1: begin
                    data_4[1][0] <= sram_dout[31:24];
                    data_4[1][1] <= sram_dout[23:16];
                    data_4[1][2] <= sram_dout[15:8];
                    data_4[1][3] <= sram_dout[7:0];
                end  
                2'd2: begin
                    data_4[2][0] <= sram_dout[31:24];
                    data_4[2][1] <= sram_dout[23:16];
                    data_4[2][2] <= sram_dout[15:8];
                    data_4[2][3] <= sram_dout[7:0];
                end  
                2'd3: begin
                    data_4[3][0] <= sram_dout[31:24];
                    data_4[3][1] <= sram_dout[23:16];
                    data_4[3][2] <= sram_dout[15:8];
                    data_4[3][3] <= sram_dout[7:0];
                end 
            endcase
        end
    end
end

always @(*) begin
    hor_available = 0;
    ver_available = 0;
    if (block_idx > 7) 
        ver_available = 1;
    if (block_idx[2:0] > 0)
        hor_available = 1;
end

reg [9:0] sum_t, sum_l, sum_l1, sum_l2, sum_l3, sum_t1, sum_t2, sum_t3;
reg [12:0] sum;
reg [7:0] dc;
reg [1:0] sad_mode, next_sad_mode; //1: VER, 2: HOR, 3: DC

reg [7:0] L0 [0:3];
reg [7:0] next_L0 [0:3];
reg [7:0] T0 [0:3][0:3];
reg [7:0] next_T0 [0:3][0:3];
reg [7:0] Tsad0 [0:15];
reg [7:0] Tsad1 [0:15];
reg [7:0] next_Tsad0 [0:15];
reg [7:0] next_Tsad1 [0:15];
reg [7:0] Lsad [0:15];
reg [7:0] next_Lsad [0:15];
reg [7:0] T_pre [0:3];
reg [7:0] L_pre [0:3]; 

always @(*) begin
    reg [5:0] idx;
    if (state == RECONSTRUCTION_0 || state == RECONSTRUCTION_L || state == RECONSTRUCTION_T || state == RECONSTRUCTION_T_L)
        idx = last_block_idx;
    else
        idx = block_idx;

    if (!cur_mode[cur_sec]) begin // 16*16
        case (idx[2:0])
            3'd0: begin
                T_pre[0] = Tsad0[0];
                T_pre[1] = Tsad0[1];
                T_pre[2] = Tsad0[2];
                T_pre[3] = Tsad0[3];
            end
            3'd1: begin
                T_pre[0] = Tsad0[4];
                T_pre[1] = Tsad0[5];
                T_pre[2] = Tsad0[6];
                T_pre[3] = Tsad0[7];
            end 
            3'd2: begin
                T_pre[0] = Tsad0[8];
                T_pre[1] = Tsad0[9];
                T_pre[2] = Tsad0[10];
                T_pre[3] = Tsad0[11];
            end
            3'd3: begin
                T_pre[0] = Tsad0[12];
                T_pre[1] = Tsad0[13];
                T_pre[2] = Tsad0[14];
                T_pre[3] = Tsad0[15];
            end
            3'd4: begin
                T_pre[0] = Tsad1[0];
                T_pre[1] = Tsad1[1];
                T_pre[2] = Tsad1[2];
                T_pre[3] = Tsad1[3];
            end
            3'd5: begin
                T_pre[0] = Tsad1[4];
                T_pre[1] = Tsad1[5];
                T_pre[2] = Tsad1[6];
                T_pre[3] = Tsad1[7];
            end 
            3'd6: begin
                T_pre[0] = Tsad1[8];
                T_pre[1] = Tsad1[9];
                T_pre[2] = Tsad1[10];
                T_pre[3] = Tsad1[11];
            end
            3'd7: begin
                T_pre[0] = Tsad1[12];
                T_pre[1] = Tsad1[13];
                T_pre[2] = Tsad1[14];
                T_pre[3] = Tsad1[15];
            end
        endcase
        case (idx[5:3])
            3'd0, 3'd4: begin // 4 36
                L_pre[0] = Lsad[0];
                L_pre[1] = Lsad[1];
                L_pre[2] = Lsad[2];
                L_pre[3] = Lsad[3];
            end 
            3'd1, 3'd5: begin // 12 44
                L_pre[0] = Lsad[4];
                L_pre[1] = Lsad[5];
                L_pre[2] = Lsad[6];
                L_pre[3] = Lsad[7];
            end
            3'd2, 3'd6: begin // 20 52
                L_pre[0] = Lsad[8];
                L_pre[1] = Lsad[9];
                L_pre[2] = Lsad[10];
                L_pre[3] = Lsad[11];
            end
            3'd3, 3'd7: begin // 28 60
                L_pre[0] = Lsad[12];
                L_pre[1] = Lsad[13];
                L_pre[2] = Lsad[14];
                L_pre[3] = Lsad[15];
            end
        endcase
    end
    else begin
        L_pre[0] = L0[0];
        L_pre[1] = L0[1];
        L_pre[2] = L0[2];
        L_pre[3] = L0[3];
        T_pre[0] = T0[idx[1:0]][0];
        T_pre[1] = T0[idx[1:0]][1];
        T_pre[2] = T0[idx[1:0]][2];
        T_pre[3] = T0[idx[1:0]][3];
        case (idx)
        //Tsad
            6'd32: begin
                T_pre[0] = Tsad0[0];
                T_pre[1] = Tsad0[1];
                T_pre[2] = Tsad0[2];
                T_pre[3] = Tsad0[3];
            end
            6'd33: begin
                T_pre[0] = Tsad0[4];
                T_pre[1] = Tsad0[5];
                T_pre[2] = Tsad0[6];
                T_pre[3] = Tsad0[7];
            end 
            6'd34: begin
                T_pre[0] = Tsad0[8];
                T_pre[1] = Tsad0[9];
                T_pre[2] = Tsad0[10];
                T_pre[3] = Tsad0[11];
            end
            6'd35: begin
                T_pre[0] = Tsad0[12];
                T_pre[1] = Tsad0[13];
                T_pre[2] = Tsad0[14];
                T_pre[3] = Tsad0[15];
            end
            6'd37: begin
                T_pre[0] = Tsad1[4];
                T_pre[1] = Tsad1[5];
                T_pre[2] = Tsad1[6];
                T_pre[3] = Tsad1[7];
            end 
            6'd38: begin
                T_pre[0] = Tsad1[8];
                T_pre[1] = Tsad1[9];
                T_pre[2] = Tsad1[10];
                T_pre[3] = Tsad1[11];
            end
            6'd39: begin
                T_pre[0] = Tsad1[12];
                T_pre[1] = Tsad1[13];
                T_pre[2] = Tsad1[14];
                T_pre[3] = Tsad1[15];
            end
            // Lasd
            6'd4: begin
                L_pre[0] = Lsad[0];
                L_pre[1] = Lsad[1];
                L_pre[2] = Lsad[2];
                L_pre[3] = Lsad[3];
            end
            6'd12, 6'd44: begin
                L_pre[0] = Lsad[4];
                L_pre[1] = Lsad[5];
                L_pre[2] = Lsad[6];
                L_pre[3] = Lsad[7];
            end
            6'd20, 6'd52: begin
                L_pre[0] = Lsad[8];
                L_pre[1] = Lsad[9];
                L_pre[2] = Lsad[10];
                L_pre[3] = Lsad[11];
            end
            6'd28, 6'd60: begin
                L_pre[0] = Lsad[12];
                L_pre[1] = Lsad[13];
                L_pre[2] = Lsad[14];
                L_pre[3] = Lsad[15];
            end
            6'd36: begin
                T_pre[0] = Tsad1[0];
                T_pre[1] = Tsad1[1];
                T_pre[2] = Tsad1[2];
                T_pre[3] = Tsad1[3];
                L_pre[0] = Lsad[0];
                L_pre[1] = Lsad[1];
                L_pre[2] = Lsad[2];
                L_pre[3] = Lsad[3];
            end
        endcase

    end
end
always @(*) begin
    sum = dc;
    if (state == INPUT_PARAM3 && !cur_mode[0]) begin
        sum = 128;
    end
    case (intra_state)
        DC_4_0: begin
            if (ver_available) begin
                if (hor_available) begin // ver hor
                    sum_t = T_pre[0] + T_pre[1] + T_pre[2] + T_pre[3];
                    sum_l = L_pre[0] + L_pre[1] + L_pre[2] + L_pre[3];
                    sum = (sum_t + sum_l) >> 3;
                end
                else begin// ver
                    sum_t = T_pre[0] + T_pre[1] + T_pre[2] + T_pre[3];
                    sum = sum_t >> 2;
                end
            end
            else begin // hor
                if (hor_available) begin
                    sum_l = L_pre[0] + L_pre[1] + L_pre[2] + L_pre[3];
                    sum = sum_l >> 2;
                end
                else
                    sum = 128;
            end
        end

        DC_16_0: begin
            case (cur_sec)
                2'd1: begin // L
                    sum_l = Lsad[0] + Lsad[1] + Lsad[2] + Lsad[3];
                    sum_l1 = Lsad[4] + Lsad[5] + Lsad[6] + Lsad[7];
                    sum_l2 = Lsad[8] + Lsad[9] + Lsad[10] + Lsad[11];
                    sum_l3 = Lsad[12] + Lsad[13] + Lsad[14] + Lsad[15];
                    sum = (sum_l + sum_l1 + sum_l2 + sum_l3) >> 4;
                end
                2'd2: begin // T
                    sum_t = Tsad0[0] + Tsad0[1] + Tsad0[2] + Tsad0[3];
                    sum_t1 = Tsad0[4] + Tsad0[5] + Tsad0[6] + Tsad0[7];
                    sum_t2 = Tsad0[8] + Tsad0[9] + Tsad0[10] + Tsad0[11];
                    sum_t3 = Tsad0[12] + Tsad0[13] + Tsad0[14] + Tsad0[15];
                    sum = (sum_t + sum_t1 + sum_t2 + sum_t3) >> 4;
                end
                2'd3: begin
                    sum_l = Lsad[0] + Lsad[1] + Lsad[2] + Lsad[3];
                    sum_l1 = Lsad[4] + Lsad[5] + Lsad[6] + Lsad[7];
                    sum_l2 = Lsad[8] + Lsad[9] + Lsad[10] + Lsad[11];
                    sum_l3 = Lsad[12] + Lsad[13] + Lsad[14] + Lsad[15];
                    sum_t = Tsad1[0] + Tsad1[1] + Tsad1[2] + Tsad1[3];
                    sum_t1 = Tsad1[4] + Tsad1[5] + Tsad1[6] + Tsad1[7];
                    sum_t2 = Tsad1[8] + Tsad1[9] + Tsad1[10] + Tsad1[11];
                    sum_t3 = Tsad1[12] + Tsad1[13] + Tsad1[14] + Tsad1[15];
                    sum = (sum_l + sum_l1 + sum_l2 + sum_l3 + sum_t + sum_t1 + sum_t2 + sum_t3) >> 5;
                end
            endcase
        end
    endcase
end


reg [7:0] sad0, sad1, sad2, sad3, sad_hor0, sad_hor1, sad_hor2, sad_hor3, sad_ver0, sad_ver1, sad_ver2, sad_ver3;
reg [11:0] sad_sum, next_sad_sum;
reg [15:0] sad_sum_dc, next_sad_sum_dc, sad_sum_hor, next_sad_sum_hor, sad_sum_ver, next_sad_sum_ver;
reg [11:0] sad_min, next_sad_min;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        /*dc <= 0;
        sad_sum <= 0;
        sad_min <= 0;
        sad_mode <= 0;
        sad_sum_dc <= 0;
        sad_sum_hor <= 0;
        sad_sum_ver <= 0;*/
    end
    else begin
        dc <= sum;
        sad_sum <= next_sad_sum;
        sad_min <= next_sad_min;
        sad_mode <= next_sad_mode;
        sad_sum_dc <= next_sad_sum_dc;
        sad_sum_hor <= next_sad_sum_hor;
        sad_sum_ver <= next_sad_sum_ver;
    end
end


reg [5:0] L_idx, T_idx;
assign L_idx = last_counter[5:4] << 2;
assign T_idx = last_counter[3:2] << 2;
always @(*) begin
    next_sad_min = sad_min;
    next_sad_mode = sad_mode;
    next_sad_sum = sad_sum;
    next_sad_sum_dc = sad_sum_dc;
    next_sad_sum_hor = sad_sum_hor;
    next_sad_sum_ver = sad_sum_ver;
    
    case (intra_state)
        INTRA_IDLE: begin
            next_sad_sum = 0;
            next_sad_min = 0;
            next_sad_sum_dc = 0;
            next_sad_sum_hor = 0;
            next_sad_sum_ver = 0;
            if (state == INPUT_PARAM3 && !cur_mode[0]) 
                next_sad_mode = 3;
        end
        DC_4: begin
            case (counter)
                2'd0: begin
                    sad0 = (data_4[0][0] > dc) ? (data_4[0][0] - dc) : (dc - data_4[0][0]);
                    sad1 = (data_4[0][1] > dc) ? (data_4[0][1] - dc) : (dc - data_4[0][1]);
                    sad2 = (data_4[0][2] > dc) ? (data_4[0][2] - dc) : (dc - data_4[0][2]);
                    sad3 = (data_4[0][3] > dc) ? (data_4[0][3] - dc) : (dc - data_4[0][3]);
                    next_sad_sum_dc = sad0 + sad1 + sad2 + sad3;

                    if (hor_available) begin
                    sad_hor0 = (data_4[0][0] > L_pre[0]) ?
                           (data_4[0][0] - L_pre[0]) : (L_pre[0] - data_4[0][0]);
                    sad_hor1 = (data_4[0][1] > L_pre[0]) ?
                           (data_4[0][1] - L_pre[0]) : (L_pre[0] - data_4[0][1]);
                    sad_hor2 = (data_4[0][2] > L_pre[0]) ?
                           (data_4[0][2] - L_pre[0]) : (L_pre[0] - data_4[0][2]);
                    sad_hor3 = (data_4[0][3] > L_pre[0]) ?
                           (data_4[0][3] - L_pre[0]) : (L_pre[0] - data_4[0][3]);
                    next_sad_sum_hor = sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end

                    if (ver_available) begin
                    sad_ver0 = (data_4[0][0] > T_pre[0]) ? 
                           (data_4[0][0] - T_pre[0]) : (T_pre[0] - data_4[0][0]);
                    sad_ver1 = (data_4[1][0] > T_pre[0]) ? 
                           (data_4[1][0] - T_pre[0]) : (T_pre[0] - data_4[1][0]);
                    sad_ver2 = (data_4[2][0] > T_pre[0]) ? 
                           (data_4[2][0] - T_pre[0]) : (T_pre[0] - data_4[2][0]);
                    sad_ver3 = (data_4[3][0] > T_pre[0]) ? 
                           (data_4[3][0] - T_pre[0]) : (T_pre[0] - data_4[3][0]);
                    next_sad_sum_ver = sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                end 
                2'd1: begin
                    sad0 = (data_4[1][0] > dc) ? (data_4[1][0] - dc) : (dc - data_4[1][0]);
                    sad1 = (data_4[1][1] > dc) ? (data_4[1][1] - dc) : (dc - data_4[1][1]);
                    sad2 = (data_4[1][2] > dc) ? (data_4[1][2] - dc) : (dc - data_4[1][2]);
                    sad3 = (data_4[1][3] > dc) ? (data_4[1][3] - dc) : (dc - data_4[1][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;

                    if (hor_available) begin
                    sad_hor0 = (data_4[1][0] > L_pre[1]) ? 
                           (data_4[1][0] - L_pre[1]) : (L_pre[1] - data_4[1][0]);
                    sad_hor1 = (data_4[1][1] > L_pre[1]) ?
                           (data_4[1][1] - L_pre[1]) : (L_pre[1] - data_4[1][1]);
                    sad_hor2 = (data_4[1][2] > L_pre[1]) ?
                           (data_4[1][2] - L_pre[1]) : (L_pre[1] - data_4[1][2]);
                    sad_hor3 = (data_4[1][3] > L_pre[1]) ?
                           (data_4[1][3] - L_pre[1]) : (L_pre[1] - data_4[1][3]);
                    next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end

                    if (ver_available) begin
                    sad_ver0 = (data_4[0][1] > T_pre[1]) ? 
                           (data_4[0][1] - T_pre[1]) : (T_pre[1] - data_4[0][1]);
                    sad_ver1 = (data_4[1][1] > T_pre[1]) ? 
                           (data_4[1][1] - T_pre[1]) : (T_pre[1] - data_4[1][1]);
                    sad_ver2 = (data_4[2][1] > T_pre[1]) ?
                           (data_4[2][1] - T_pre[1]) : (T_pre[1] - data_4[2][1]);
                    sad_ver3 = (data_4[3][1] > T_pre[1]) ? 
                           (data_4[3][1] - T_pre[1]) : (T_pre[1] - data_4[3][1]);
                    next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                end 
                2'd2: begin
                    sad0 = (data_4[2][0] > dc) ? (data_4[2][0] - dc) : (dc - data_4[2][0]);
                    sad1 = (data_4[2][1] > dc) ? (data_4[2][1] - dc) : (dc - data_4[2][1]);
                    sad2 = (data_4[2][2] > dc) ? (data_4[2][2] - dc) : (dc - data_4[2][2]);
                    sad3 = (data_4[2][3] > dc) ? (data_4[2][3] - dc) : (dc - data_4[2][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;

                    if (hor_available) begin
                    sad_hor0 = (data_4[2][0] > L_pre[2]) ?
                           (data_4[2][0] - L_pre[2]) : (L_pre[2] - data_4[2][0]);
                    sad_hor1 = (data_4[2][1] > L_pre[2]) ?
                           (data_4[2][1] - L_pre[2]) : (L_pre[2] - data_4[2][1]);
                    sad_hor2 = (data_4[2][2] > L_pre[2]) ?
                           (data_4[2][2] - L_pre[2]) : (L_pre[2] - data_4[2][2]);
                    sad_hor3 = (data_4[2][3] > L_pre[2]) ?
                           (data_4[2][3] - L_pre[2]) : (L_pre[2] - data_4[2][3]);
                    next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end

                    if (ver_available) begin
                    sad_ver0 = (data_4[0][2] > T_pre[2]) ? 
                           (data_4[0][2] - T_pre[2]) : (T_pre[2] - data_4[0][2]);
                    sad_ver1 = (data_4[1][2] > T_pre[2]) ?
                           (data_4[1][2] - T_pre[2]) : (T_pre[2] - data_4[1][2]);
                    sad_ver2 = (data_4[2][2] > T_pre[2]) ?
                           (data_4[2][2] - T_pre[2]) : (T_pre[2] - data_4[2][2]);
                    sad_ver3 = (data_4[3][2] > T_pre[2]) ? 
                           (data_4[3][2] - T_pre[2]) : (T_pre[2] - data_4[3][2]);
                    next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                end
                2'd3: begin
                    sad0 = (data_4[3][0] > dc) ? (data_4[3][0] - dc) : (dc - data_4[3][0]);
                    sad1 = (data_4[3][1] > dc) ? (data_4[3][1] - dc) : (dc - data_4[3][1]);
                    sad2 = (data_4[3][2] > dc) ? (data_4[3][2] - dc) : (dc - data_4[3][2]);
                    sad3 = (data_4[3][3] > dc) ? (data_4[3][3] - dc) : (dc - data_4[3][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;

                    if (hor_available) begin
                    sad_hor0 = (data_4[3][0] > L_pre[3]) ?
                           (data_4[3][0] - L_pre[3]) : (L_pre[3] - data_4[3][0]);
                    sad_hor1 = (data_4[3][1] > L_pre[3]) ?
                           (data_4[3][1] - L_pre[3]) : (L_pre[3] - data_4[3][1]);
                    sad_hor2 = (data_4[3][2] > L_pre[3]) ?
                           (data_4[3][2] - L_pre[3]) : (L_pre[3] - data_4[3][2]);
                    sad_hor3 = (data_4[3][3] > L_pre[3]) ?
                           (data_4[3][3] - L_pre[3]) : (L_pre[3] - data_4[3][3]);
                    next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end

                    if (ver_available) begin
                    sad_ver0 = (data_4[0][3] > T_pre[3]) ? 
                           (data_4[0][3] - T_pre[3]) : (T_pre[3] - data_4[0][3]);
                    sad_ver1 = (data_4[1][3] > T_pre[3]) ?
                           (data_4[1][3] - T_pre[3]) : (T_pre[3] - data_4[1][3]);
                    sad_ver2 = (data_4[2][3] > T_pre[3]) ?
                           (data_4[2][3] - T_pre[3]) : (T_pre[3] - data_4[2][3]);
                    sad_ver3 = (data_4[3][3] > T_pre[3]) ? 
                           (data_4[3][3] - T_pre[3]) : (T_pre[3] - data_4[3][3]);
                    next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end


                    if (ver_available) begin
                        if (hor_available) begin
                            if (next_sad_sum_hor <= next_sad_sum_ver) begin
                                if (next_sad_sum_dc <= next_sad_sum_hor) // DC
                                    next_sad_mode = 3;
                                else // HOR
                                    next_sad_mode = 2;
                            end
                            else begin
                                if (next_sad_sum_dc <= next_sad_sum_ver) // DC
                                    next_sad_mode = 3;
                                else // VER
                                    next_sad_mode = 1;
                            end
                        end
                        else begin
                            if (next_sad_sum_dc <= next_sad_sum_ver) // DC
                                next_sad_mode = 3;
                            else // VER
                                next_sad_mode = 1;
                        end
                    end
                    else begin 
                        if (hor_available) begin
                            if (next_sad_sum_dc <= next_sad_sum_hor) // DC
                                next_sad_mode = 3;
                            else // HOR
                                next_sad_mode = 2;
                        end
                        else
                            next_sad_mode = 3;
                    end
                end
            endcase
        end

        SAD_16: begin
            case (counter[1:0]) //DC
                2'd1: begin
                    sad0 = (data_4[0][0] > dc) ? (data_4[0][0] - dc) : (dc - data_4[0][0]);
                    sad1 = (data_4[0][1] > dc) ? (data_4[0][1] - dc) : (dc - data_4[0][1]);
                    sad2 = (data_4[0][2] > dc) ? (data_4[0][2] - dc) : (dc - data_4[0][2]);
                    sad3 = (data_4[0][3] > dc) ? (data_4[0][3] - dc) : (dc - data_4[0][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;
                end 
                2'd2: begin
                    sad0 = (data_4[1][0] > dc) ? (data_4[1][0] - dc) : (dc - data_4[1][0]);
                    sad1 = (data_4[1][1] > dc) ? (data_4[1][1] - dc) : (dc - data_4[1][1]);
                    sad2 = (data_4[1][2] > dc) ? (data_4[1][2] - dc) : (dc - data_4[1][2]);
                    sad3 = (data_4[1][3] > dc) ? (data_4[1][3] - dc) : (dc - data_4[1][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;
                end 
                2'd3: begin
                    sad0 = (data_4[2][0] > dc) ? (data_4[2][0] - dc) : (dc - data_4[2][0]);
                    sad1 = (data_4[2][1] > dc) ? (data_4[2][1] - dc) : (dc - data_4[2][1]);
                    sad2 = (data_4[2][2] > dc) ? (data_4[2][2] - dc) : (dc - data_4[2][2]);
                    sad3 = (data_4[2][3] > dc) ? (data_4[2][3] - dc) : (dc - data_4[2][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;
                end
                2'd0: begin
                    sad0 = (data_4[3][0] > dc) ? (data_4[3][0] - dc) : (dc - data_4[3][0]);
                    sad1 = (data_4[3][1] > dc) ? (data_4[3][1] - dc) : (dc - data_4[3][1]);
                    sad2 = (data_4[3][2] > dc) ? (data_4[3][2] - dc) : (dc - data_4[3][2]);
                    sad3 = (data_4[3][3] > dc) ? (data_4[3][3] - dc) : (dc - data_4[3][3]);
                    next_sad_sum_dc = sad_sum_dc + sad0 + sad1 + sad2 + sad3;
                end
            endcase

            if (cur_sec == 1 || cur_sec == 3) begin // HOR
                case (counter[1:0])
                    2'd1: begin
                        sad_hor0 = (data_4[0][0] > Lsad[L_idx]) ? (data_4[0][0] - Lsad[L_idx]) : (Lsad[L_idx] - data_4[0][0]);
                        sad_hor1 = (data_4[0][1] > Lsad[L_idx]) ? (data_4[0][1] - Lsad[L_idx]) : (Lsad[L_idx] - data_4[0][1]);
                        sad_hor2 = (data_4[0][2] > Lsad[L_idx]) ? (data_4[0][2] - Lsad[L_idx]) : (Lsad[L_idx] - data_4[0][2]);
                        sad_hor3 = (data_4[0][3] > Lsad[L_idx]) ? (data_4[0][3] - Lsad[L_idx]) : (Lsad[L_idx] - data_4[0][3]);
                        next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end 
                    2'd2: begin
                        sad_hor0 = (data_4[1][0] > Lsad[L_idx + 1]) ? (data_4[1][0] - Lsad[L_idx + 1]) : (Lsad[L_idx + 1] - data_4[1][0]);
                        sad_hor1 = (data_4[1][1] > Lsad[L_idx + 1]) ? (data_4[1][1] - Lsad[L_idx + 1]) : (Lsad[L_idx + 1] - data_4[1][1]);
                        sad_hor2 = (data_4[1][2] > Lsad[L_idx + 1]) ? (data_4[1][2] - Lsad[L_idx + 1]) : (Lsad[L_idx + 1] - data_4[1][2]);
                        sad_hor3 = (data_4[1][3] > Lsad[L_idx + 1]) ? (data_4[1][3] - Lsad[L_idx + 1]) : (Lsad[L_idx + 1] - data_4[1][3]);
                        next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end 
                    2'd3: begin
                        sad_hor0 = (data_4[2][0] > Lsad[L_idx + 2]) ? (data_4[2][0] - Lsad[L_idx + 2]) : (Lsad[L_idx + 2] - data_4[2][0]);
                        sad_hor1 = (data_4[2][1] > Lsad[L_idx + 2]) ? (data_4[2][1] - Lsad[L_idx + 2]) : (Lsad[L_idx + 2] - data_4[2][1]);
                        sad_hor2 = (data_4[2][2] > Lsad[L_idx + 2]) ? (data_4[2][2] - Lsad[L_idx + 2]) : (Lsad[L_idx + 2] - data_4[2][2]);
                        sad_hor3 = (data_4[2][3] > Lsad[L_idx + 2]) ? (data_4[2][3] - Lsad[L_idx + 2]) : (Lsad[L_idx + 2] - data_4[2][3]);
                        next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end
                    2'd0: begin
                        sad_hor0 = (data_4[3][0] > Lsad[L_idx + 3]) ? (data_4[3][0] - Lsad[L_idx + 3]) : (Lsad[L_idx + 3] - data_4[3][0]);
                        sad_hor1 = (data_4[3][1] > Lsad[L_idx + 3]) ? (data_4[3][1] - Lsad[L_idx + 3]) : (Lsad[L_idx + 3] - data_4[3][1]);
                        sad_hor2 = (data_4[3][2] > Lsad[L_idx + 3]) ? (data_4[3][2] - Lsad[L_idx + 3]) : (Lsad[L_idx + 3] - data_4[3][2]);
                        sad_hor3 = (data_4[3][3] > Lsad[L_idx + 3]) ? (data_4[3][3] - Lsad[L_idx + 3]) : (Lsad[L_idx + 3] - data_4[3][3]);
                        next_sad_sum_hor = sad_sum_hor + sad_hor0 + sad_hor1 + sad_hor2 + sad_hor3;
                    end
                endcase
            end


            if (cur_sec == 2) begin // VER
                case (counter[1:0])
                    2'd1: begin
                        sad_ver0 = (data_4[0][0] > Tsad0[T_idx]) ? (data_4[0][0] - Tsad0[T_idx]) : (Tsad0[T_idx] - data_4[0][0]);
                        sad_ver1 = (data_4[0][1] > Tsad0[T_idx + 1]) ? (data_4[0][1] - Tsad0[T_idx + 1]) : (Tsad0[T_idx + 1] - data_4[0][1]);
                        sad_ver2 = (data_4[0][2] > Tsad0[T_idx + 2]) ? (data_4[0][2] - Tsad0[T_idx + 2]) : (Tsad0[T_idx + 2] - data_4[0][2]);
                        sad_ver3 = (data_4[0][3] > Tsad0[T_idx + 3]) ? (data_4[0][3] - Tsad0[T_idx + 3]) : (Tsad0[T_idx + 3] - data_4[0][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end 
                    2'd2: begin
                        sad_ver0 = (data_4[1][0] > Tsad0[T_idx]) ? (data_4[1][0] - Tsad0[T_idx]) : (Tsad0[T_idx] - data_4[1][0]);
                        sad_ver1 = (data_4[1][1] > Tsad0[T_idx + 1]) ? (data_4[1][1] - Tsad0[T_idx + 1]) : (Tsad0[T_idx + 1] - data_4[1][1]);
                        sad_ver2 = (data_4[1][2] > Tsad0[T_idx + 2]) ? (data_4[1][2] - Tsad0[T_idx + 2]) : (Tsad0[T_idx + 2] - data_4[1][2]);
                        sad_ver3 = (data_4[1][3] > Tsad0[T_idx + 3]) ? (data_4[1][3] - Tsad0[T_idx + 3]) : (Tsad0[T_idx + 3] - data_4[1][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end 
                    2'd3: begin
                        sad_ver0 = (data_4[2][0] > Tsad0[T_idx]) ? (data_4[2][0] - Tsad0[T_idx]) : (Tsad0[T_idx] - data_4[2][0]);
                        sad_ver1 = (data_4[2][1] > Tsad0[T_idx + 1]) ? (data_4[2][1] - Tsad0[T_idx + 1]) : (Tsad0[T_idx + 1] - data_4[2][1]);
                        sad_ver2 = (data_4[2][2] > Tsad0[T_idx + 2]) ? (data_4[2][2] - Tsad0[T_idx + 2]) : (Tsad0[T_idx + 2] - data_4[2][2]);
                        sad_ver3 = (data_4[2][3] > Tsad0[T_idx + 3]) ? (data_4[2][3] - Tsad0[T_idx + 3]) : (Tsad0[T_idx + 3] - data_4[2][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                    2'd0: begin
                        sad_ver0 = (data_4[3][0] > Tsad0[T_idx]) ? (data_4[3][0] - Tsad0[T_idx]) : (Tsad0[T_idx] - data_4[3][0]);
                        sad_ver1 = (data_4[3][1] > Tsad0[T_idx + 1]) ? (data_4[3][1] - Tsad0[T_idx + 1]) : (Tsad0[T_idx + 1] - data_4[3][1]);
                        sad_ver2 = (data_4[3][2] > Tsad0[T_idx + 2]) ? (data_4[3][2] - Tsad0[T_idx + 2]) : (Tsad0[T_idx + 2] - data_4[3][2]);
                        sad_ver3 = (data_4[3][3] > Tsad0[T_idx + 3]) ? (data_4[3][3] - Tsad0[T_idx + 3]) : (Tsad0[T_idx + 3] - data_4[3][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                endcase
            end
            if (cur_sec == 3) begin // VER
                case (counter[1:0])
                    2'd1: begin
                        sad_ver0 = (data_4[0][0] > Tsad1[T_idx]) ? (data_4[0][0] - Tsad1[T_idx]) : (Tsad1[T_idx] - data_4[0][0]);
                        sad_ver1 = (data_4[0][1] > Tsad1[T_idx + 1]) ? (data_4[0][1] - Tsad1[T_idx + 1]) : (Tsad1[T_idx + 1] - data_4[0][1]);
                        sad_ver2 = (data_4[0][2] > Tsad1[T_idx + 2]) ? (data_4[0][2] - Tsad1[T_idx + 2]) : (Tsad1[T_idx + 2] - data_4[0][2]);
                        sad_ver3 = (data_4[0][3] > Tsad1[T_idx + 3]) ? (data_4[0][3] - Tsad1[T_idx + 3]) : (Tsad1[T_idx + 3] - data_4[0][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end 
                    2'd2: begin
                        sad_ver0 = (data_4[1][0] > Tsad1[T_idx]) ? (data_4[1][0] - Tsad1[T_idx]) : (Tsad1[T_idx] - data_4[1][0]);
                        sad_ver1 = (data_4[1][1] > Tsad1[T_idx + 1]) ? (data_4[1][1] - Tsad1[T_idx + 1]) : (Tsad1[T_idx + 1] - data_4[1][1]);
                        sad_ver2 = (data_4[1][2] > Tsad1[T_idx + 2]) ? (data_4[1][2] - Tsad1[T_idx + 2]) : (Tsad1[T_idx + 2] - data_4[1][2]);
                        sad_ver3 = (data_4[1][3] > Tsad1[T_idx + 3]) ? (data_4[1][3] - Tsad1[T_idx + 3]) : (Tsad1[T_idx + 3] - data_4[1][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end 
                    2'd3: begin
                        sad_ver0 = (data_4[2][0] > Tsad1[T_idx]) ? (data_4[2][0] - Tsad1[T_idx]) : (Tsad1[T_idx] - data_4[2][0]);
                        sad_ver1 = (data_4[2][1] > Tsad1[T_idx + 1]) ? (data_4[2][1] - Tsad1[T_idx + 1]) : (Tsad1[T_idx + 1] - data_4[2][1]);
                        sad_ver2 = (data_4[2][2] > Tsad1[T_idx + 2]) ? (data_4[2][2] - Tsad1[T_idx + 2]) : (Tsad1[T_idx + 2] - data_4[2][2]);
                        sad_ver3 = (data_4[2][3] > Tsad1[T_idx + 3]) ? (data_4[2][3] - Tsad1[T_idx + 3]) : (Tsad1[T_idx + 3] - data_4[2][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                    2'd0: begin
                        sad_ver0 = (data_4[3][0] > Tsad1[T_idx]) ? (data_4[3][0] - Tsad1[T_idx]) : (Tsad1[T_idx] - data_4[3][0]);
                        sad_ver1 = (data_4[3][1] > Tsad1[T_idx + 1]) ? (data_4[3][1] - Tsad1[T_idx + 1]) : (Tsad1[T_idx + 1] - data_4[3][1]);
                        sad_ver2 = (data_4[3][2] > Tsad1[T_idx + 2]) ? (data_4[3][2] - Tsad1[T_idx + 2]) : (Tsad1[T_idx + 2] - data_4[3][2]);
                        sad_ver3 = (data_4[3][3] > Tsad1[T_idx + 3]) ? (data_4[3][3] - Tsad1[T_idx + 3]) : (Tsad1[T_idx + 3] - data_4[3][3]);
                        next_sad_sum_ver = sad_sum_ver + sad_ver0 + sad_ver1 + sad_ver2 + sad_ver3;
                    end
                endcase
            end

            if (counter == 65) begin
                case (cur_sec)
                    2'd1: begin
                        if (sad_sum_dc <= sad_sum_hor) begin // DC
                            next_sad_mode = 3;
                        end
                        else begin // HOR
                            next_sad_mode = 2;
                        end
                    end
                    2'd2: begin
                        if (sad_sum_dc <= sad_sum_ver) begin // DC
                            next_sad_mode = 3;
                        end
                        else begin // VER
                            next_sad_mode = 1;
                        end
                    end
                    2'd3: begin
                        if (sad_sum_hor <= sad_sum_ver) begin
                            if (sad_sum_dc <= sad_sum_hor) // DC
                                next_sad_mode = 3;
                            else // HOR
                                next_sad_mode = 2;
                        end
                        else begin
                            if (sad_sum_dc <= sad_sum_ver) // DC
                                next_sad_mode = 3;
                            else // VER
                                next_sad_mode = 1;
                        end
                    end
                endcase
            end
        end
    endcase
end

//==================================================================
// CALCULATION
//==================================================================
reg signed [28:0] new_data[0:3][0:3];
reg signed [28:0] next_new_data[0:3][0:3];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        /*new_data[0][0] <= 0;
        new_data[0][1] <= 0;
        new_data[0][2] <= 0;
        new_data[0][3] <= 0;
        new_data[1][0] <= 0;
        new_data[1][1] <= 0;
        new_data[1][2] <= 0;
        new_data[1][3] <= 0;
        new_data[2][0] <= 0;
        new_data[2][1] <= 0;
        new_data[2][2] <= 0;
        new_data[2][3] <= 0;
        new_data[3][0] <= 0;
        new_data[3][1] <= 0;
        new_data[3][2] <= 0;
        new_data[3][3] <= 0;*/
    end 
    else begin
        new_data[0][0] <= next_new_data[0][0];
        new_data[0][1] <= next_new_data[0][1];
        new_data[0][2] <= next_new_data[0][2];
        new_data[0][3] <= next_new_data[0][3];
        new_data[1][0] <= next_new_data[1][0];
        new_data[1][1] <= next_new_data[1][1];
        new_data[1][2] <= next_new_data[1][2];
        new_data[1][3] <= next_new_data[1][3];
        new_data[2][0] <= next_new_data[2][0];
        new_data[2][1] <= next_new_data[2][1];
        new_data[2][2] <= next_new_data[2][2];
        new_data[2][3] <= next_new_data[2][3];
        new_data[3][0] <= next_new_data[3][0];
        new_data[3][1] <= next_new_data[3][1];
        new_data[3][2] <= next_new_data[3][2];
        new_data[3][3] <= next_new_data[3][3];
    end
end

wire signed [15:0] Y [0:3][0:3];
wire signed [15:0] r0_t0, r0_t1, r0_t2, r0_t3;
// Row 0
assign r0_t0 = new_data[0][0] + new_data[0][3];
assign r0_t1 = new_data[0][0] - new_data[0][3];
assign r0_t2 = new_data[0][1] + new_data[0][2];
assign r0_t3 = new_data[0][1] - new_data[0][2];
assign Y[0][0] = r0_t0 + r0_t2;
assign Y[0][1] = r0_t1 + r0_t3;
assign Y[0][2] = r0_t0 - r0_t2;
assign Y[0][3] = r0_t1 - r0_t3;
// Row 1
wire signed [15:0] r1_t0, r1_t1, r1_t2, r1_t3;
assign r1_t0 = new_data[1][0] + new_data[1][3];
assign r1_t1 = new_data[1][0] - new_data[1][3];
assign r1_t2 = new_data[1][1] + new_data[1][2];
assign r1_t3 = new_data[1][1] - new_data[1][2];
assign Y[1][0] = r1_t0 + r1_t2;
assign Y[1][1] = r1_t1 + r1_t3;
assign Y[1][2] = r1_t0 - r1_t2;
assign Y[1][3] = r1_t1 - r1_t3;
// Row 2
wire signed [15:0] r2_t0, r2_t1, r2_t2, r2_t3;
assign r2_t0 = new_data[2][0] + new_data[2][3];
assign r2_t1 = new_data[2][0] - new_data[2][3];
assign r2_t2 = new_data[2][1] + new_data[2][2];
assign r2_t3 = new_data[2][1] - new_data[2][2];
assign Y[2][0] = r2_t0 + r2_t2;
assign Y[2][1] = r2_t1 + r2_t3;
assign Y[2][2] = r2_t0 - r2_t2;
assign Y[2][3] = r2_t1 - r2_t3;
// Row 3
wire signed [15:0] r3_t0, r3_t1, r3_t2, r3_t3;
assign r3_t0 = new_data[3][0] + new_data[3][3];
assign r3_t1 = new_data[3][0] - new_data[3][3];
assign r3_t2 = new_data[3][1] + new_data[3][2];
assign r3_t3 = new_data[3][1] - new_data[3][2];
assign Y[3][0] = r3_t0 + r3_t2;
assign Y[3][1] = r3_t1 + r3_t3;
assign Y[3][2] = r3_t0 - r3_t2;
assign Y[3][3] = r3_t1 - r3_t3;

// Column 0
wire signed [16:0] c0_t0, c0_t1, c0_t2, c0_t3;
assign c0_t0 = Y[0][0] + Y[3][0];
assign c0_t1 = Y[0][0] - Y[3][0];
assign c0_t2 = Y[1][0] + Y[2][0];
assign c0_t3 = Y[1][0] - Y[2][0];
// Column 1
wire signed [16:0] c1_t0, c1_t1, c1_t2, c1_t3;
assign c1_t0 = Y[0][1] + Y[3][1];
assign c1_t1 = Y[0][1] - Y[3][1];
assign c1_t2 = Y[1][1] + Y[2][1];
assign c1_t3 = Y[1][1] - Y[2][1];
// Column 2
wire signed [16:0] c2_t0, c2_t1, c2_t2, c2_t3;
assign c2_t0 = Y[0][2] + Y[3][2];
assign c2_t1 = Y[0][2] - Y[3][2];
assign c2_t2 = Y[1][2] + Y[2][2];
assign c2_t3 = Y[1][2] - Y[2][2];
// Column 3
wire signed [16:0] c3_t0, c3_t1, c3_t2, c3_t3;
assign c3_t0 = Y[0][3] + Y[3][3];
assign c3_t1 = Y[0][3] - Y[3][3];
assign c3_t2 = Y[1][3] + Y[2][3];
assign c3_t3 = Y[1][3] - Y[2][3];


reg [4:0] qbits;
reg [17:0] f;
reg [13:0] mf_a, mf_b, mf_c;
reg [4:0] v_a, v_b, v_c;
wire [2:0] qp_mod6;
reg [13:0] MF [0:3][0:3];
reg [4:0] V [0:3][0:3];
reg [4:0] scale_shift;

assign qp_mod6 = cur_qp % 6;
assign scale_shift = cur_qp / 6;
always @(*) begin
    qbits = 15 + scale_shift;
    case (cur_qp)
        5'd0, 5'd1, 5'd2, 5'd3, 5'd4, 5'd5:       f = 18'd10922;
        5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11:     f = 18'd21845;
        5'd12, 5'd13, 5'd14, 5'd15, 5'd16, 5'd17: f = 18'd43690;
        5'd18, 5'd19, 5'd20, 5'd21, 5'd22, 5'd23: f = 18'd87381;
        default:                                  f = 18'd174762; // QP 24~29
    endcase
end
always @(*) begin
    case (qp_mod6)
        3'd0: begin 
            mf_a = 14'd13107; mf_b = 14'd5243; mf_c = 14'd8066;
            v_a  = 5'd10;     v_b  = 5'd16;    v_c  = 5'd13;
        end
        3'd1: begin 
            mf_a = 14'd11916; mf_b = 14'd4660; mf_c = 14'd7490;
            v_a  = 5'd11;     v_b  = 5'd18;    v_c  = 5'd14;
        end
        3'd2: begin 
            mf_a = 14'd10082; mf_b = 14'd4194; mf_c = 14'd6554;
            v_a  = 5'd13;     v_b  = 5'd20;    v_c  = 5'd16;
        end
        3'd3: begin 
            mf_a = 14'd9362;  mf_b = 14'd3647; mf_c = 14'd5825;
            v_a  = 5'd14;     v_b  = 5'd23;    v_c  = 5'd18;
        end
        3'd4: begin 
            mf_a = 14'd8192;  mf_b = 14'd3355; mf_c = 14'd5243;
            v_a  = 5'd16;     v_b  = 5'd25;    v_c  = 5'd20;
        end
        3'd5: begin 
            mf_a = 14'd7282;  mf_b = 14'd2893; mf_c = 14'd4559;
            v_a  = 5'd18;     v_b  = 5'd29;    v_c  = 5'd23;
        end
        default: begin 
            mf_a = 14'd13107; mf_b = 14'd5243; mf_c = 14'd8066;
            v_a  = 5'd10;     v_b  = 5'd16;    v_c  = 5'd13;
        end
    endcase
end
always @(*) begin
    MF[0][0] = mf_a; MF[0][1] = mf_c; MF[0][2] = mf_a; MF[0][3] = mf_c;
    MF[1][0] = mf_c; MF[1][1] = mf_b; MF[1][2] = mf_c; MF[1][3] = mf_b;
    MF[2][0] = mf_a; MF[2][1] = mf_c; MF[2][2] = mf_a; MF[2][3] = mf_c;
    MF[3][0] = mf_c; MF[3][1] = mf_b; MF[3][2] = mf_c; MF[3][3] = mf_b;
end
always @(*) begin
    V[0][0] = v_a; V[0][1] = v_c; V[0][2] = v_a; V[0][3] = v_c;
    V[1][0] = v_c; V[1][1] = v_b; V[1][2] = v_c; V[1][3] = v_b;
    V[2][0] = v_a; V[2][1] = v_c; V[2][2] = v_a; V[2][3] = v_c;
    V[3][0] = v_c; V[3][1] = v_b; V[3][2] = v_c; V[3][3] = v_b;
end

reg flag;
reg [10:0] predict[0:6];
always @(*) begin
    flag = 0;
    predict[0] = 0;
    predict[1] = 0;
    predict[2] = 0;
    predict[3] = 0;
    predict[4] = 0;
    predict[5] = 0;
    predict[6] = 0;
    for (integer i = 0; i < 4; i = i + 1) begin
        for (integer j = 0; j < 4; j = j + 1) begin
            next_new_data[i][j] = new_data[i][j];
        end
    end
    case (state)
        RESIDUAL: begin
            case (sad_mode)
                2'd3: begin // DC
                    next_new_data[counter - 1][0] = data_4[counter - 1][0] - dc;
                    next_new_data[counter - 1][1] = data_4[counter - 1][1] - dc;
                    next_new_data[counter - 1][2] = data_4[counter - 1][2] - dc;
                    next_new_data[counter - 1][3] = data_4[counter - 1][3] - dc;
                end
                2'd2: begin // HOR
                    next_new_data[counter - 1][0] = data_4[counter - 1][0] - L_pre[counter - 1];
                    next_new_data[counter - 1][1] = data_4[counter - 1][1] - L_pre[counter - 1];
                    next_new_data[counter - 1][2] = data_4[counter - 1][2] - L_pre[counter - 1];
                    next_new_data[counter - 1][3] = data_4[counter - 1][3] - L_pre[counter - 1];
                end
                2'd1: begin // VER
                    next_new_data[counter - 1][0] = data_4[counter - 1][0] - T_pre[0];
                    next_new_data[counter - 1][1] = data_4[counter - 1][1] - T_pre[1];
                    next_new_data[counter - 1][2] = data_4[counter - 1][2] - T_pre[2];
                    next_new_data[counter - 1][3] = data_4[counter - 1][3] - T_pre[3];
                end
            endcase
        end
        INTEGER_TRANSFORM: begin // W
            next_new_data[0][0] = c0_t0 + c0_t2;
            next_new_data[1][0] = c0_t1 + c0_t3;
            next_new_data[2][0] = c0_t0 - c0_t2;
            next_new_data[3][0] = c0_t1 - c0_t3;

            next_new_data[0][1] = c1_t0 + c1_t2;
            next_new_data[1][1] = c1_t1 + c1_t3;
            next_new_data[2][1] = c1_t0 - c1_t2;
            next_new_data[3][1] = c1_t1 - c1_t3;

            next_new_data[0][2] = c2_t0 + c2_t2;
            next_new_data[1][2] = c2_t1 + c2_t3;
            next_new_data[2][2] = c2_t0 - c2_t2;
            next_new_data[3][2] = c2_t1 - c2_t3;

            next_new_data[0][3] = c3_t0 + c3_t2;
            next_new_data[1][3] = c3_t1 + c3_t3;
            next_new_data[2][3] = c3_t0 - c3_t2;
            next_new_data[3][3] = c3_t1 - c3_t3;
        end
        QUANTIZATION_1: begin
            for (integer i = 0; i < 4; i = i + 1) begin
                for (integer j = 0; j < 4; j = j + 1) begin
                    next_new_data[i][j] = new_data[i][j] * MF[i][j];
                end
            end
        end
        QUANTIZATION_2: begin
            for (integer i = 0; i < 4; i = i + 1) begin
                for (integer j = 0; j < 4; j = j + 1) begin
                    reg [28:0] temp;
                    reg [28:0] temp1;
                    temp = (new_data[i][j][28]) ? (~new_data[i][j] + 1 + f) : (new_data[i][j] + f);
                    temp1 = temp >> qbits;
                    next_new_data[i][j] = (new_data[i][j][28]) ? (~temp1 + 1) : temp1;
                end
            end
        end


        RECONSTRUCTION_T, RECONSTRUCTION_L, RECONSTRUCTION_T_L, RECONSTRUCTION_0: begin
            case (counter)
                2'd0: begin
                    for (integer i = 0; i < 4; i = i + 1) begin
                        for (integer j = 0; j < 4; j = j + 1) begin
                            next_new_data[i][j] = (new_data[i][j] * V[i][j]) ;
                        end
                    end
                end
                2'd1: begin
                    next_new_data[0][3] = (c3_t0 + c3_t2) ;
                    next_new_data[1][3] = (c3_t1 + c3_t3);
                    next_new_data[2][3] = (c3_t0 - c3_t2) ;
                    next_new_data[3][3] = (c3_t1 - c3_t3) ;
                    next_new_data[3][0] = (c0_t1 - c0_t3);
                    next_new_data[3][1] = (c1_t1 - c1_t3);
                    next_new_data[3][2] = (c2_t1 - c2_t3);
                end
                2'd2: begin
                    if (!cur_mode[cur_sec]) begin // 16*16
                        case (block_idx)
                            6'd8, 6'd16, 6'd24: begin // 3 11 19 DC
                                for (integer i = 0 ; i < 4 ; i = i + 1 ) begin
                                    reg signed [22:0] temp;
                                    temp = dc + (new_data[i][3] >>> (6 - scale_shift));
                                    if (temp[22])
                                        next_new_data[i][3] = 0;
                                    else if (temp > 255)
                                        next_new_data[i][3] = 255;
                                    else
                                        next_new_data[i][3] = temp;
                                end
                            end
                            6'd40, 6'd48, 6'd56, 6'd36: begin // 35 43 51 59
                                case (sad_mode)
                                    2'd1: begin // VER
                                        predict[0] = Tsad0[15];
                                        predict[1] = Tsad0[15];
                                        predict[2] = Tsad0[15];
                                        predict[3] = Tsad0[15];
                                    end 
                                    //2'd2: begin // HOR
                                    //end
                                    2'd3: begin // DC
                                        predict[0] = dc;
                                        predict[1] = dc;
                                        predict[2] = dc;
                                        predict[3] = dc;
                                    end 
                                endcase
                                for (integer i = 0 ; i < 4 ; i = i + 1 ) begin
                                    reg signed [22:0] temp;
                                    temp = predict[i] + (new_data[i][3] >>> (6 - scale_shift));
                                    if (temp[22])
                                        next_new_data[i][3] = 0;
                                    else if (temp > 255)
                                        next_new_data[i][3] = 255;
                                    else
                                        next_new_data[i][3] = temp;
                                end
                            end
                            6'd25, 6'd26, 6'd27: begin //24 25 26
                                for (integer i = 0 ; i < 4 ; i = i + 1 ) begin
                                    reg signed [22:0] temp;
                                    temp = dc + (new_data[3][i] >>> (6 - scale_shift));
                                    if (temp[22])
                                        next_new_data[3][i] = 0;
                                    else if (temp > 255)
                                        next_new_data[3][i] = 255;
                                    else
                                        next_new_data[3][i] = temp;
                                end
                            end
                            6'd29, 6'd30, 6'd31, 6'd32: begin // 28 29 30 31
                                case (sad_mode)
                                    //2'd1: begin // VER
                                    //end 
                                    2'd2: begin // HOR
                                        predict[0] = Lsad[15];
                                        predict[1] = Lsad[15];
                                        predict[2] = Lsad[15];
                                        predict[3] = Lsad[15];
                                    end
                                    2'd3: begin // DC
                                        predict[0] = dc;
                                        predict[1] = dc;
                                        predict[2] = dc;
                                        predict[3] = dc;
                                    end 
                                endcase
                                for (integer i = 0 ; i < 4 ; i = i + 1 ) begin
                                    reg signed [22:0] temp;
                                    temp = predict[i] + (new_data[3][i] >>> (6 - scale_shift));
                                    if (temp[22])
                                        next_new_data[3][i] = 0;
                                    else if (temp > 255)
                                        next_new_data[3][i] = 255;
                                    else
                                        next_new_data[3][i] = temp;
                                end
                            end
                            6'd4: begin //27
                                for (integer i = 0 ; i < 4 ; i = i + 1 ) begin
                                    reg signed [22:0] temp;
                                    temp = dc + (new_data[3][i] >>> (6 - scale_shift));
                                    if (temp[22])
                                        next_new_data[3][i] = 0;
                                    else if (temp > 255)
                                        next_new_data[3][i] = 255;
                                    else
                                        next_new_data[3][i] = temp;
                                end
                                for (integer i = 0 ; i < 3 ; i = i + 1 ) begin
                                    reg signed [22:0] temp;
                                    temp = dc + (new_data[i][3] >>> (6 - scale_shift));
                                    if (temp[22])
                                        next_new_data[i][3] = 0;
                                    else if (temp > 255)
                                        next_new_data[i][3] = 255;
                                    else
                                        next_new_data[i][3] = temp;
                                end
                            end
                        endcase
                    end
                    else begin // 4*4
                        case (sad_mode)
                            2'd1: begin // VER
                                predict[0] = T_pre[0];
                                predict[1] = T_pre[1];
                                predict[2] = T_pre[2];
                                predict[3] = T_pre[3];
                                predict[4] = T_pre[3];
                                predict[5] = T_pre[3];
                                predict[6] = T_pre[3];
                            end 
                            2'd2: begin // HOR
                                predict[0] = L_pre[3];
                                predict[1] = L_pre[3];
                                predict[2] = L_pre[3];
                                predict[3] = L_pre[3];
                                predict[4] = L_pre[0];
                                predict[5] = L_pre[1];
                                predict[6] = L_pre[2];
                            end
                            2'd3: begin // DC
                                predict[0] = dc;
                                predict[1] = dc;
                                predict[2] = dc;
                                predict[3] = dc;
                                predict[4] = dc;
                                predict[5] = dc;
                                predict[6] = dc;
                            end 
                        endcase
                        for (integer i = 0 ; i < 4 ; i = i + 1 ) begin
                            reg signed [22:0] temp;
                            temp = predict[i] + (new_data[3][i] >>> (6 - scale_shift));
                            if (temp[22])
                                next_new_data[3][i] = 0;
                            else if (temp>255)
                                next_new_data[3][i] = 255;
                            else
                                next_new_data[3][i] = temp;
                        end
                        for (integer i = 0 ; i < 3 ; i = i + 1 ) begin
                            reg signed [22:0] temp;
                            temp = predict[i + 4] + (new_data[i][3] >>> (6 - scale_shift));
                            if (temp[22])
                                next_new_data[i][3] = 0;
                            else if (temp > 255)
                                next_new_data[i][3] = 255;
                            else
                                next_new_data[i][3] = temp;
                        end
                    end
                end
                2'd3: begin
                    for (integer i = 0; i < 4; i = i + 1) begin
                        for (integer j = 0; j < 4; j = j + 1) begin
                            next_new_data[i][j] = 0;
                        end
                    end
                end
            endcase
        end
    endcase
end


//==================================================================
// OUTPUT
//==================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out_value <= 0;
    end 
    else begin
        out_valid <= next_out_valid;
        out_value <= next_out_value;
    end
end

always @(*) begin
    next_out_valid = 0;
    next_out_value = 0;
    if (state == OUTPUT) begin
        next_out_valid = 1;
        next_out_value = new_data[counter[3:2]][counter[1:0]];
    end
end


//==================================================================
// RECONSTRUCTION
//==================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for (integer i = 0 ; i < 16 ; i = i + 1) begin
            Tsad0[i] <= 0;
            Tsad1[i] <= 0;
            Lsad[i] <= 0;
        end
        for (integer i = 0 ; i < 4 ; i = i + 1) begin
            L0[i] <= 0;
            for (integer j = 0 ; j < 4 ; j = j + 1) begin
                T0[i][j] <= 0;
            end
        end
    end
    else begin
        for (integer i = 0 ; i < 16 ; i = i + 1) begin
            Tsad0[i] <= next_Tsad0[i];
            Tsad1[i] <= next_Tsad1[i];
            Lsad[i] <= next_Lsad[i];
        end
        for (integer i = 0 ; i < 4 ; i = i + 1) begin
            L0[i] <= next_L0[i];
            for (integer j = 0 ; j < 4 ; j = j + 1) begin
                T0[i][j] <= next_T0[i][j];
            end
        end
    end
end

reg [1:0] T0_idx;
assign T0_idx = block_idx - 1;
always @(*) begin
    next_Tsad0 = Tsad0;
    next_Tsad1 = Tsad1;
    next_Lsad = Lsad;
    next_T0 = T0;
    next_L0 = L0;
    case (state)
        RECONSTRUCTION_L: begin
            if (counter == 3) begin
            case (block_idx)
                //6'd3, 6'd11, 6'd19, 6'd35, 6'd43, 6'd51, 6'd59: 
                6'd8, 6'd40: begin // 3 ,35
                    next_Lsad[0] = new_data[0][3];
                    next_Lsad[1] = new_data[1][3];
                    next_Lsad[2] = new_data[2][3];
                    next_Lsad[3] = new_data[3][3];
                end
                6'd16, 6'd48: begin // 11, 43
                    next_Lsad[4] = new_data[0][3];
                    next_Lsad[5] = new_data[1][3];
                    next_Lsad[6] = new_data[2][3];
                    next_Lsad[7] = new_data[3][3];
                end
                6'd24, 6'd56: begin // 19, 51
                    next_Lsad[8] = new_data[0][3];
                    next_Lsad[9] = new_data[1][3];
                    next_Lsad[10] = new_data[2][3];
                    next_Lsad[11] = new_data[3][3];
                end
                6'd36: begin //59
                    next_Lsad[12] = new_data[0][3];
                    next_Lsad[13] = new_data[1][3];
                    next_Lsad[14] = new_data[2][3];
                    next_Lsad[15] = new_data[3][3];
                end
            endcase
            end
        end 
        RECONSTRUCTION_T: begin
            if (counter == 3) begin
            case (block_idx)
                6'd25: begin //24
                    next_Tsad0[0] = new_data[3][0];
                    next_Tsad0[1] = new_data[3][1];
                    next_Tsad0[2] = new_data[3][2];
                    next_Tsad0[3] = new_data[3][3];
                end 
                6'd26: begin //25
                    next_Tsad0[4] = new_data[3][0];
                    next_Tsad0[5] = new_data[3][1];
                    next_Tsad0[6] = new_data[3][2];
                    next_Tsad0[7] = new_data[3][3];
                end 
                6'd27: begin //26
                    next_Tsad0[8] = new_data[3][0];
                    next_Tsad0[9] = new_data[3][1];
                    next_Tsad0[10] = new_data[3][2];
                    next_Tsad0[11] = new_data[3][3];
                end 
                6'd29: begin //28
                    next_Tsad1[0] = new_data[3][0];
                    next_Tsad1[1] = new_data[3][1];
                    next_Tsad1[2] = new_data[3][2];
                    next_Tsad1[3] = new_data[3][3];
                end 
                6'd30: begin //29
                    next_Tsad1[4] = new_data[3][0];
                    next_Tsad1[5] = new_data[3][1];
                    next_Tsad1[6] = new_data[3][2];
                    next_Tsad1[7] = new_data[3][3];
                end 
                6'd31: begin //30
                    next_Tsad1[8] = new_data[3][0];
                    next_Tsad1[9] = new_data[3][1];
                    next_Tsad1[10] = new_data[3][2];
                    next_Tsad1[11] = new_data[3][3];
                end 
                6'd32: begin //31
                    next_Tsad1[12] = new_data[3][0];
                    next_Tsad1[13] = new_data[3][1];
                    next_Tsad1[14] = new_data[3][2];
                    next_Tsad1[15] = new_data[3][3];
                end 
            endcase
            end
        end
        RECONSTRUCTION_T_L: begin // 27
            if (counter == 3) begin
                next_Lsad[12] = new_data[0][3];
                next_Lsad[13] = new_data[1][3];
                next_Lsad[14] = new_data[2][3];
                next_Lsad[15] = new_data[3][3];

                next_Tsad0[12] = new_data[3][0];
                next_Tsad0[13] = new_data[3][1];
                next_Tsad0[14] = new_data[3][2];
                next_Tsad0[15] = new_data[3][3];
            end
        end 
        RECONSTRUCTION_0: begin // 27
            if (counter == 3) begin
                next_T0[T0_idx[1:0]][0] = new_data[3][0];
                next_T0[T0_idx[1:0]][1] = new_data[3][1];
                next_T0[T0_idx[1:0]][2] = new_data[3][2];
                next_T0[T0_idx[1:0]][3] = new_data[3][3];

                next_L0[0] = new_data[0][3];
                next_L0[1] = new_data[1][3];
                next_L0[2] = new_data[2][3];
                next_L0[3] = new_data[3][3];
                
                case (block_idx)
                    6'd25: begin //24
                        next_Tsad0[0] = new_data[3][0];
                        next_Tsad0[1] = new_data[3][1];
                        next_Tsad0[2] = new_data[3][2];
                        next_Tsad0[3] = new_data[3][3];
                    end 
                    6'd26: begin //25
                        next_Tsad0[4] = new_data[3][0];
                        next_Tsad0[5] = new_data[3][1];
                        next_Tsad0[6] = new_data[3][2];
                        next_Tsad0[7] = new_data[3][3];
                    end 
                    6'd27: begin //26
                        next_Tsad0[8] = new_data[3][0];
                        next_Tsad0[9] = new_data[3][1];
                        next_Tsad0[10] = new_data[3][2];
                        next_Tsad0[11] = new_data[3][3];
                    end 
                    6'd29: begin //28
                        next_Tsad1[0] = new_data[3][0];
                        next_Tsad1[1] = new_data[3][1];
                        next_Tsad1[2] = new_data[3][2];
                        next_Tsad1[3] = new_data[3][3];
                    end 
                    6'd30: begin //29
                        next_Tsad1[4] = new_data[3][0];
                        next_Tsad1[5] = new_data[3][1];
                        next_Tsad1[6] = new_data[3][2];
                        next_Tsad1[7] = new_data[3][3];
                    end 
                    6'd31: begin //30
                        next_Tsad1[8] = new_data[3][0];
                        next_Tsad1[9] = new_data[3][1];
                        next_Tsad1[10] = new_data[3][2];
                        next_Tsad1[11] = new_data[3][3];
                    end 
                    6'd32: begin //31
                        next_Tsad1[12] = new_data[3][0];
                        next_Tsad1[13] = new_data[3][1];
                        next_Tsad1[14] = new_data[3][2];
                        next_Tsad1[15] = new_data[3][3];
                    end 
                    6'd8, 6'd40: begin // 3 ,35
                        next_Lsad[0] = new_data[0][3];
                        next_Lsad[1] = new_data[1][3];
                        next_Lsad[2] = new_data[2][3];
                        next_Lsad[3] = new_data[3][3];
                    end
                    6'd16, 6'd48: begin // 11, 43
                        next_Lsad[4] = new_data[0][3];
                        next_Lsad[5] = new_data[1][3];
                        next_Lsad[6] = new_data[2][3];
                        next_Lsad[7] = new_data[3][3];
                    end
                    6'd24, 6'd56: begin // 19, 51
                        next_Lsad[8] = new_data[0][3];
                        next_Lsad[9] = new_data[1][3];
                        next_Lsad[10] = new_data[2][3];
                        next_Lsad[11] = new_data[3][3];
                    end
                    6'd36: begin //59
                        next_Lsad[12] = new_data[0][3];
                        next_Lsad[13] = new_data[1][3];
                        next_Lsad[14] = new_data[2][3];
                        next_Lsad[15] = new_data[3][3];
                    end
                    6'd4: begin //27
                        next_Lsad[12] = new_data[0][3];
                        next_Lsad[13] = new_data[1][3];
                        next_Lsad[14] = new_data[2][3];
                        next_Lsad[15] = new_data[3][3];

                        next_Tsad0[12] = new_data[3][0];
                        next_Tsad0[13] = new_data[3][1];
                        next_Tsad0[14] = new_data[3][2];
                        next_Tsad0[15] = new_data[3][3];
                    end
                endcase
                
            end
        end 
    endcase
    
end





endmodule