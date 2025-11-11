module SUDOKU(
    //Input Port
    clk,
    rst_n,
	in_valid,
	in,

    //Output Port
    out_valid,
    out
    );

//==============================
//   INPUT/OUTPUT DECLARATION
//==============================
input clk;
input rst_n;
input in_valid;
input [3:0] in;

output reg out_valid;
output reg [3:0] out;
    
//==============================
//   PARAMETER DECLARATION
//==============================
parameter IDLE     = 2'd0;
parameter SOLVE    = 2'd1;
parameter OUTPUT   = 2'd2;

//==============================
//   LOGIC DECLARATION                                                 
//==============================
reg [1:0] state, next_state;
reg [6:0] input_cnt, next_input_cnt; //0~80
reg [6:0] output_cnt, next_output_cnt; //0~80
reg next_out_valid;
reg [3:0] next_out;

reg [3:0] grid [0:80];
reg [3:0] next_grid [0:80];

reg done;

reg [6:0] check_idx;
reg [3:0] test_num;
reg [3:0] possible_count;
reg [3:0] last_possible;

reg can_place_num [1:9];

reg [3:0] row, col;
reg [6:0] row_idx, box_idx;
reg [6:0] check_pos, check_pos1, check_pos2;

//==============================
//   Design                                                            
//==============================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
        state <= IDLE;
    else 
        state <= next_state;
end
always @(*) begin
    case (state)
        IDLE: 
            next_state = in_valid ? SOLVE : IDLE;
        SOLVE: 
            next_state = (done) ? OUTPUT : SOLVE;
        OUTPUT: 
            next_state = (output_cnt == 80) ? IDLE : OUTPUT;
        default: 
            next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_cnt <= 0;
        for (integer i = 0; i < 81; i = i + 1) begin
            grid[i] <= 0;
        end
    end
    else begin
        input_cnt <= next_input_cnt;
        for (integer i = 0; i < 81; i = i + 1) begin
            grid[i] <= next_grid[i];
        end
    end
end

always @(*) begin
    next_input_cnt = 0;
    next_grid = grid;
    if (in_valid && next_state != OUTPUT) begin
        next_input_cnt = input_cnt + 1;
        next_grid[input_cnt] = in;
    end
    else if (state == IDLE) begin
        for (integer i = 0; i < 81; i = i + 1) begin
            next_grid[i] = 0;
        end
    end

    for (integer i = 0; i < 81; i = i + 1) begin
        if (grid[i] == 0) begin  
            row = i / 9;
            row_idx = row * 9;
            col = i - row_idx;
            case (i)
                7'd0, 7'd1, 7'd2, 7'd9, 7'd10, 7'd11, 7'd18, 7'd19, 7'd20: box_idx = 0;
                7'd3, 7'd4, 7'd5, 7'd12, 7'd13, 7'd14, 7'd21, 7'd22, 7'd23: box_idx = 3;
                7'd6, 7'd7, 7'd8, 7'd15, 7'd16, 7'd17, 7'd24, 7'd25, 7'd26: box_idx = 6;
                7'd27, 7'd28, 7'd29, 7'd36, 7'd37, 7'd38, 7'd45, 7'd46, 7'd47: box_idx = 27;
                7'd30, 7'd31, 7'd32, 7'd39, 7'd40, 7'd41, 7'd48, 7'd49, 7'd50: box_idx = 30;
                7'd33, 7'd34, 7'd35, 7'd42, 7'd43, 7'd44, 7'd51, 7'd52, 7'd53: box_idx = 33;
                7'd54, 7'd55, 7'd56, 7'd63, 7'd64, 7'd65, 7'd72, 7'd73, 7'd74: box_idx = 54;
                7'd57, 7'd58, 7'd59, 7'd66, 7'd67, 7'd68, 7'd75, 7'd76, 7'd77: box_idx = 57;
                7'd60, 7'd61, 7'd62, 7'd69, 7'd70, 7'd71, 7'd78, 7'd79, 7'd80: box_idx = 60;
                default: box_idx = 0;
            endcase
            
            //check naked single
            possible_count = 0;
            last_possible = 0;
            for (integer i = 1; i <= 9 ; i = i + 1) begin
                can_place_num[i] = 0;
            end
                
            for (integer test_num = 1; test_num <= 9; test_num = test_num + 1) begin
                reg can_place; 
                can_place = 1;
                
                // check row
                if (grid[row_idx]     == test_num || grid[row_idx + 1] == test_num || 
                    grid[row_idx + 2] == test_num || grid[row_idx + 3] == test_num || 
                    grid[row_idx + 4] == test_num || grid[row_idx + 5] == test_num || 
                    grid[row_idx + 6] == test_num || grid[row_idx + 7] == test_num || 
                    grid[row_idx + 8] == test_num) can_place = 0;

                // check column
                if (can_place && (
                    grid[col]      == test_num || grid[col + 9]  == test_num || 
                    grid[col + 18] == test_num || grid[col + 27] == test_num || 
                    grid[col + 36] == test_num || grid[col + 45] == test_num || 
                    grid[col + 54] == test_num || grid[col + 63] == test_num || 
                    grid[col + 72] == test_num)) can_place = 0;
                
                // check box
                if (can_place &&(
                    grid[box_idx]      == test_num || grid[box_idx + 1]  == test_num || 
                    grid[box_idx + 2]  == test_num || grid[box_idx + 9]  == test_num || 
                    grid[box_idx + 10] == test_num || grid[box_idx + 11] == test_num || 
                    grid[box_idx + 18] == test_num || grid[box_idx + 19] == test_num || 
                    grid[box_idx + 20] == test_num)) can_place = 0;

                if (can_place) begin
                    possible_count = possible_count + 1;
                    last_possible = test_num;
                    can_place_num[test_num] = 1;
                end
            end
            //naked single found
            if (possible_count == 1) begin
                next_grid[i] = last_possible;
            end
            
            //check hidden single
            else begin
                reg other_can_place;
                reg is_hidden_single;
                reg [3:0] hidden_number;
                hidden_number = 0;
                is_hidden_single = 0;
                
                for (integer test_num = 1; test_num <= 9; test_num = test_num + 1) begin
                    if (hidden_number == 0 && can_place_num[test_num]) begin
                        
                        //check hidden row single
                        is_hidden_single = 1;

                        //box c = 0, 1, 2
                        case (row)
                            4'd0, 4'd1, 4'd2: check_pos = 0;
                            4'd3, 4'd4, 4'd5: check_pos = 27;
                            4'd6, 4'd7, 4'd8: check_pos = 54;
                            default: check_pos = 0;
                        endcase
                        if (!(grid[check_pos]    == test_num || grid[check_pos + 1]  == test_num || 
                            grid[check_pos + 2]  == test_num || grid[check_pos + 9]  == test_num || 
                            grid[check_pos + 10] == test_num || grid[check_pos + 11] == test_num || 
                            grid[check_pos + 18] == test_num || grid[check_pos + 19] == test_num || 
                            grid[check_pos + 20] == test_num)) begin

                            if (((row_idx) != i && grid[row_idx] == 0 && 
                                !(grid[0] == test_num || grid[9]  == test_num || grid[18] == test_num || grid[27] == test_num || 
                                grid[36] == test_num || grid[45] == test_num || grid[54] == test_num || grid[63] == test_num || 
                                grid[72] == test_num)) ||
                                ((row_idx + 1) != i && grid[row_idx + 1] == 0 && 
                                !(grid[1] == test_num || grid[10]  == test_num || grid[19] == test_num || grid[28] == test_num || 
                                grid[37] == test_num || grid[46] == test_num || grid[55] == test_num || grid[64] == test_num || 
                                grid[73] == test_num)) ||
                                ((row_idx + 2) != i && grid[row_idx + 2] == 0 && 
                                !(grid[2] == test_num || grid[11]  == test_num || grid[20] == test_num || grid[29] == test_num || 
                                grid[38] == test_num || grid[47] == test_num || grid[56] == test_num || grid[65] == test_num || 
                                grid[74] == test_num))) is_hidden_single = 0;
                        end

                        //box c = 3, 4, 5
                        case (row)
                            4'd0, 4'd1, 4'd2: check_pos = 3;
                            4'd3, 4'd4, 4'd5: check_pos = 30;
                            4'd6, 4'd7, 4'd8: check_pos = 57;
                            default: check_pos = 0;
                        endcase
                        if (!(grid[check_pos]    == test_num || grid[check_pos + 1]  == test_num || 
                            grid[check_pos + 2]  == test_num || grid[check_pos + 9]  == test_num || 
                            grid[check_pos + 10] == test_num || grid[check_pos + 11] == test_num || 
                            grid[check_pos + 18] == test_num || grid[check_pos + 19] == test_num || 
                            grid[check_pos + 20] == test_num)) begin
                            //c = 3
                            if (((row_idx + 3) != i && grid[row_idx + 3] == 0 && 
                                !(grid[3] == test_num || grid[12]  == test_num || grid[21] == test_num || grid[30] == test_num || 
                                grid[39] == test_num || grid[48] == test_num || grid[57] == test_num || grid[66] == test_num || 
                                grid[75] == test_num)) 
                            || ((row_idx + 4) != i && grid[row_idx + 4] == 0 && 
                                !(grid[4] == test_num || grid[13]  == test_num || grid[22] == test_num || grid[31] == test_num || 
                                grid[40] == test_num || grid[49] == test_num || grid[58] == test_num || grid[67] == test_num || 
                                grid[76] == test_num)) 
                            ||((row_idx + 5) != i && grid[row_idx + 5] == 0 && 
                                !(grid[5]  == test_num || grid[14]  == test_num || grid[23] == test_num || grid[32] == test_num || 
                                grid[41] == test_num || grid[50] == test_num || grid[59] == test_num || grid[68] == test_num || 
                                grid[77] == test_num))) is_hidden_single = 0;
                        end

                        //box c = 6, 7, 8
                        case (row)
                            4'd0, 4'd1, 4'd2: check_pos = 6;
                            4'd3, 4'd4, 4'd5: check_pos = 33;
                            4'd6, 4'd7, 4'd8: check_pos = 60;
                            default: check_pos = 0;
                        endcase
                        if (!(grid[check_pos]    == test_num || grid[check_pos + 1]  == test_num || 
                            grid[check_pos + 2]  == test_num || grid[check_pos + 9]  == test_num || 
                            grid[check_pos + 10] == test_num || grid[check_pos + 11] == test_num || 
                            grid[check_pos + 18] == test_num || grid[check_pos + 19] == test_num || 
                            grid[check_pos + 20] == test_num)) begin
                            //c = 6
                            if (((row_idx + 6) != i && grid[row_idx + 6] == 0 &&
                                !(grid[6] == test_num || grid[15]  == test_num || grid[24] == test_num || grid[33] == test_num || 
                                grid[42] == test_num || grid[51] == test_num || grid[60] == test_num || grid[69] == test_num || 
                                grid[78] == test_num))
                            || ((row_idx + 7) != i && grid[row_idx + 7] == 0 &&
                                !(grid[7] == test_num || grid[16]  == test_num || grid[25] == test_num || grid[34] == test_num || 
                                grid[43] == test_num || grid[52] == test_num || grid[61] == test_num || grid[70] == test_num || 
                                grid[79] == test_num))
                            || ((row_idx + 8) != i && grid[row_idx + 8] == 0 &&
                                !(grid[8]  == test_num || grid[17]  == test_num || grid[26] == test_num || grid[35] == test_num || 
                                grid[44] == test_num || grid[53] == test_num || grid[62] == test_num || grid[71] == test_num || 
                                grid[80] == test_num))) is_hidden_single = 0;
                        end

                        //hidden row single found
                        if (is_hidden_single) begin
                            next_grid[i] = test_num;
                            hidden_number = test_num;
                        end
                    

                        //check hidden column single
                        is_hidden_single = 1;

                        //box r = 0, 1, 2
                        case (col)
                            4'd0, 4'd1, 4'd2: check_pos = 0;
                            4'd3, 4'd4, 4'd5: check_pos = 3;
                            4'd6, 4'd7, 4'd8: check_pos = 6;
                            default: check_pos = 0;
                        endcase
                        if (!(grid[check_pos]    == test_num || grid[check_pos + 1]  == test_num || 
                            grid[check_pos + 2]  == test_num || grid[check_pos + 9]  == test_num || 
                            grid[check_pos + 10] == test_num || grid[check_pos + 11] == test_num || 
                            grid[check_pos + 18] == test_num || grid[check_pos + 19] == test_num || 
                            grid[check_pos + 20] == test_num)) begin
                            //r = 0
                            if (((col) != i && grid[col] == 0 &&
                                !(grid[0]  == test_num || grid[1] == test_num || grid[2] == test_num || grid[3] == test_num || 
                                grid[4] == test_num || grid[5] == test_num || grid[6] == test_num || grid[7] == test_num || 
                                grid[8] == test_num))
                            || ((col + 9) != i && grid[col + 9] == 0 &&
                                !(grid[9]  == test_num || grid[10] == test_num || grid[11] == test_num || grid[12] == test_num || 
                                grid[13] == test_num || grid[14] == test_num || grid[15] == test_num || grid[16] == test_num || 
                                grid[17] == test_num))
                            || ((col + 18) != i && grid[col + 18] == 0 &&
                                !(grid[18]  == test_num || grid[19] == test_num || grid[20] == test_num || grid[21] == test_num || 
                                grid[22] == test_num || grid[23] == test_num || grid[24] == test_num || grid[25] == test_num || 
                                grid[26] == test_num))) is_hidden_single = 0;
                        end

                        //box r = 3, 4, 5
                        case (col)
                            4'd0, 4'd1, 4'd2: check_pos = 27;
                            4'd3, 4'd4, 4'd5: check_pos = 30;
                            4'd6, 4'd7, 4'd8: check_pos = 33;
                            default: check_pos = 0;
                        endcase
                        if (!(grid[check_pos]    == test_num || grid[check_pos + 1]  == test_num || 
                            grid[check_pos + 2]  == test_num || grid[check_pos + 9]  == test_num || 
                            grid[check_pos + 10] == test_num || grid[check_pos + 11] == test_num || 
                            grid[check_pos + 18] == test_num || grid[check_pos + 19] == test_num || 
                            grid[check_pos + 20] == test_num)) begin
                            //r = 3
                            if (((col + 27) != i && grid[col + 27] == 0 &&
                                !(grid[27]  == test_num || grid[28] == test_num || grid[29] == test_num || grid[30] == test_num || 
                                grid[31] == test_num || grid[32] == test_num || grid[33] == test_num || grid[34] == test_num || 
                                grid[35] == test_num))
                            || ((col + 36) != i && grid[col + 36] == 0 &&
                                !(grid[36]  == test_num || grid[37] == test_num || grid[38] == test_num || grid[39] == test_num || 
                                grid[40] == test_num || grid[41] == test_num || grid[42] == test_num || grid[43] == test_num || 
                                grid[44] == test_num))
                            || ((col + 45) != i && grid[col + 45] == 0 &&
                                !(grid[45]  == test_num || grid[46] == test_num || grid[47] == test_num || grid[48] == test_num || 
                                grid[49] == test_num || grid[50] == test_num || grid[51] == test_num || grid[52] == test_num || 
                                grid[53] == test_num))) is_hidden_single = 0;
                        end

                        //box r = 6, 7, 8
                        case (col)
                            4'd0, 4'd1, 4'd2: check_pos = 54;
                            4'd3, 4'd4, 4'd5: check_pos = 57;
                            4'd6, 4'd7, 4'd8: check_pos = 60;
                            default: check_pos = 0;
                        endcase
                        if (!(grid[check_pos]    == test_num || grid[check_pos + 1]  == test_num || 
                            grid[check_pos + 2]  == test_num || grid[check_pos + 9]  == test_num || 
                            grid[check_pos + 10] == test_num || grid[check_pos + 11] == test_num || 
                            grid[check_pos + 18] == test_num || grid[check_pos + 19] == test_num || 
                            grid[check_pos + 20] == test_num)) begin
                            //r = 6
                            if (((col + 54) != i && grid[col + 54] == 0 &&
                                !(grid[54]  == test_num || grid[55] == test_num || grid[56] == test_num || grid[57] == test_num || 
                                grid[58] == test_num || grid[59] == test_num || grid[60] == test_num || grid[61] == test_num || 
                                grid[62] == test_num))
                            || ((col + 63) != i && grid[col + 63] == 0 &&
                                !(grid[63]  == test_num || grid[64] == test_num || grid[65] == test_num || grid[66] == test_num || 
                                grid[67] == test_num || grid[68] == test_num || grid[69] == test_num || grid[70] == test_num || 
                                grid[71] == test_num))
                            || ((col + 72) != i && grid[col + 72] == 0 &&
                                !(grid[72]  == test_num || grid[73] == test_num || grid[74] == test_num || grid[75] == test_num || 
                                grid[76] == test_num || grid[77] == test_num || grid[78] == test_num || grid[79] == test_num || 
                                grid[80] == test_num))) is_hidden_single = 0;
                        end

                        //hidden column single found
                        if (is_hidden_single) begin
                            next_grid[i] = test_num;
                            hidden_number = test_num;
                        end

                        //check hidden box single
                        is_hidden_single = 1;
                        for (integer pos = 0; pos < 9; pos = pos + 1) begin
                            case (pos)
                                4'd0: check_idx = box_idx;
                                4'd1: check_idx = box_idx + 1;
                                4'd2: check_idx = box_idx + 2; 
                                4'd3: check_idx = box_idx + 9;
                                4'd4: check_idx = box_idx + 10;
                                4'd5: check_idx = box_idx + 11;
                                4'd6: check_idx = box_idx + 18;
                                4'd7: check_idx = box_idx + 19;
                                4'd8: check_idx = box_idx + 20;
                                default:  check_idx = 0;
                            endcase

                            if (check_idx != i && grid[check_idx] == 0) begin
                                other_can_place = 1;
                                
                                //row
                                check_pos1 = check_idx / 9 * 9;
                                if (grid[check_pos1]     == test_num || grid[check_pos1 + 1] == test_num || 
                                    grid[check_pos1 + 2] == test_num || grid[check_pos1 + 3] == test_num || 
                                    grid[check_pos1 + 4] == test_num || grid[check_pos1 + 5] == test_num || 
                                    grid[check_pos1 + 6] == test_num || grid[check_pos1 + 7] == test_num || 
                                    grid[check_pos1 + 8] == test_num) other_can_place = 0;
                                
                                //column
                                check_pos2 = check_idx - check_pos1;
                                if (other_can_place && (
                                    grid[check_pos2]      == test_num || grid[check_pos2 + 9]  == test_num || 
                                    grid[check_pos2 + 18] == test_num || grid[check_pos2 + 27] == test_num || 
                                    grid[check_pos2 + 36] == test_num || grid[check_pos2 + 45] == test_num || 
                                    grid[check_pos2 + 54] == test_num || grid[check_pos2 + 63] == test_num || 
                                    grid[check_pos2 + 72] == test_num)) other_can_place = 0;

                                if (other_can_place) begin
                                    is_hidden_single = 0;
                                end
                            end
                        end
                        //hidden box single found
                        if (is_hidden_single) begin
                            next_grid[i] = test_num;
                            hidden_number = test_num;
                        end
                    end
                end                 
            end
        end
    end
end

always@(*) begin
    done = 1;
    if(state == SOLVE) begin
        for (integer i = 0 ; i < 81 ; i = i + 1) begin
            if (grid[i] == 0) 
                done = 0;
        end
    end
end

always @(*) begin
    if (state == OUTPUT) begin
        next_out_valid = 1;
        next_out = grid[output_cnt];
        next_output_cnt = output_cnt + 1;
    end
    else begin
        next_out_valid = 0;
        next_out = 0;
        next_output_cnt = 0;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out <= 0;
        output_cnt <= 0;
    end
    else begin
        out_valid <= next_out_valid;
        out <= next_out;
        output_cnt <= next_output_cnt;
    end
end

endmodule
//12:00
//247