//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : RPG.sv
//   	Module Name : RPG
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module RPG(input clk, INF.RPG_inf inf);
import usertype::*;
//==============================================//
//              Logic Declaration               //
//==============================================//
parameter DRAM_BASE = 17'h10000;  // Starting address for player data
//---------- Input Capture Registers ----------//
Action          current_action;
Training_Type   current_train_type;
Mode            current_mode;
Date            current_date;
Player_No       current_player_no;
Attribute       monster_attr[0:2];      // [0]=attack, [1]=defense, [2]=HP
Attribute       skill_mp[0:3];
logic [1:0]     monster_cnt, skill_cnt;

//---------- Player Data Registers ----------//
Player_Info     cur_player;
Player_Info     updated_player, updated_player_reg;

//---------- State Machine ----------//
typedef enum logic [3:0] {
    IDLE        = 4'd0,
    INPUT_WAIT  = 4'd1,
    READ_ADDR   = 4'd2,
    READ_WAIT   = 4'd3,
    READ_DATA   = 4'd4,
    COMPUTE     = 4'd5,
    WRITE_ADDR  = 4'd6,
    WRITE_DATA  = 4'd7,
    WRITE_RESP  = 4'd8,
    OUTPUT      = 4'd9
} State;

State state, next_state;

//---------- Computation Results ----------//
logic           operation_complete, operation_complete_reg;
Warn_Msg        warning_message, warning_message_reg;

//==============================================//
//         Output Signals                       //
//==============================================//

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.out_valid <= 0;
        inf.complete  <= 0;
        inf.warn_msg  <= No_Warn;
    end
    else begin
        if (state == OUTPUT) begin
            inf.out_valid <= 1;
            inf.complete  <= operation_complete_reg;
            inf.warn_msg  <= warning_message_reg;
        end
        else begin
            inf.out_valid <= 0;
            inf.complete  <= 0;
            inf.warn_msg  <= No_Warn;
        end
    end
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        operation_complete_reg <= 1;
        warning_message_reg <= No_Warn;
        updated_player_reg <= 0;
    end
    else if (state == COMPUTE) begin
        operation_complete_reg <= operation_complete;
        warning_message_reg <= warning_message;
        updated_player_reg <= updated_player;
    end
end



//==============================================//
//         AXI4-Lite Output Signals            //
//==============================================//

//---------- AXI Read Address Channel ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.AR_VALID <= 0;
        inf.AR_ADDR  <= 0;
    end
    else begin
        if (state == READ_ADDR && !inf.AR_VALID) begin
            inf.AR_VALID <= 1;
            inf.AR_ADDR  <= DRAM_BASE + ({9'd0, current_player_no} * 17'd12);
        end
        else if (inf.AR_VALID && inf.AR_READY) begin
            inf.AR_VALID <= 0;
        end
    end
end

//---------- AXI Read Data Channel ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.R_READY <= 0;
    end
    else begin
        if (state == READ_WAIT) begin
            inf.R_READY <= 1;
        end
        else if (inf.R_VALID && inf.R_READY) begin
            inf.R_READY <= 0;
        end
    end
end

//---------- AXI Write Address Channel ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.AW_VALID <= 0;
        inf.AW_ADDR  <= 0;
    end else begin
        if (state == WRITE_ADDR && !inf.AW_VALID) begin
            inf.AW_VALID <= 1;
            inf.AW_ADDR  <= DRAM_BASE + ({9'd0, current_player_no} * 17'd12);
        end
        else if (inf.AW_VALID && inf.AW_READY) begin
            inf.AW_VALID <= 0;
        end
    end
end

//---------- AXI Write Data Channel ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.W_VALID <= 0;
        inf.W_DATA  <= 0;
    end else begin
        if (state == WRITE_DATA && !inf.W_VALID) begin
            inf.W_VALID <= 1;
            inf.W_DATA <= {
                updated_player_reg.HP,
                4'b0, updated_player_reg.M,
                3'b0, updated_player_reg.D,
                updated_player_reg.Attack,
                updated_player_reg.Defense,
                updated_player_reg.Exp,
                updated_player_reg.MP
            };
        end
        else if (inf.W_VALID && inf.W_READY) begin
            inf.W_VALID <= 0;
        end
    end
end

//---------- AXI Write Response Channel ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.B_READY <= 0;
    end else begin
        if (state == WRITE_RESP) begin
            inf.B_READY <= 1;
        end
        else if (inf.B_VALID && inf.B_READY) begin
            inf.B_READY <= 0;
        end
    end
end

//==============================================//
//            Input Capture Logic              //
//==============================================//

//---------- Action Selection ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        current_action <= Login;
    end
    else if (inf.sel_action_valid) begin
        current_action <= inf.D.d_act[0];
    end
end

//---------- Training Type ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        current_train_type <= Type_A;
    end
    else if (inf.type_valid) begin
        current_train_type <= inf.D.d_type[0];
    end
end

//---------- Mode Selection ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        current_mode <= Easy;
    end
    else if (inf.mode_valid) begin
        current_mode <= inf.D.d_mode[0];
    end
end

//---------- Date Input ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        current_date <= 0;
    end
    else if (inf.date_valid) begin
        current_date <= inf.D.d_date[0];
    end
end

//---------- Player Number ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        current_player_no <= 0;
    end
    else if (inf.player_no_valid) begin
        current_player_no <= inf.D.d_player_no[0];
    end
end

//---------- Monster Attributes (3 inputs) ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        monster_attr[0] <= 0;
        monster_attr[1] <= 0;
        monster_attr[2] <= 0;
        monster_cnt <= 0;
    end
    else if (inf.monster_valid) begin
        monster_attr[monster_cnt] <= inf.D.d_attribute[0];
        monster_cnt <= monster_cnt + 1;
    end
    else if (state == IDLE) begin
        monster_cnt <= 0;
    end
end

//---------- Skill MP Costs (4 inputs) ----------//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        skill_mp[0] <= 0;
        skill_mp[1] <= 0;
        skill_mp[2] <= 0;
        skill_mp[3] <= 0;
        skill_cnt <= 0;
    end
    else if (inf.MP_valid) begin
        skill_mp[skill_cnt] <= inf.D.d_attribute[0];
        skill_cnt <= skill_cnt + 1;
    end
    else if (state == IDLE) begin
        skill_cnt <= 0;
    end
end

//==============================================//
//           Player Data Capture               //
//==============================================//

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        cur_player <= 0;
    end
    else if (inf.R_VALID && inf.R_READY) begin
        cur_player.MP      <= inf.R_DATA[15:0];
        cur_player.Exp     <= inf.R_DATA[31:16];
        cur_player.Defense <= inf.R_DATA[47:32];
        cur_player.Attack  <= inf.R_DATA[63:48];
        cur_player.D       <= inf.R_DATA[68:64];
        cur_player.M       <= inf.R_DATA[75:72];
        cur_player.HP      <= inf.R_DATA[95:80];
    end
    else if (state == OUTPUT) begin
        // Update cur_player with computation results
        cur_player <= updated_player_reg;
    end
end

//==============================================//
//              State Machine                  //
//==============================================//
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if (inf.sel_action_valid)
                next_state = INPUT_WAIT;
        end

        INPUT_WAIT: begin
            case (current_action)
                Login: begin
                    if (inf.player_no_valid)
                        next_state = READ_ADDR;
                end
                Level_Up: begin
                    if (inf.player_no_valid)
                        next_state = READ_ADDR;
                end
                Battle: begin
                    if (monster_cnt == 3)
                        next_state = READ_ADDR;
                end
                Use_Skill: begin
                    if (inf.MP_valid && skill_cnt == 3)
                        next_state = READ_ADDR;
                end
                Check_Inactive: begin
                    if (inf.player_no_valid)
                        next_state = READ_ADDR;
                end
            endcase
        end
        
        READ_ADDR: begin
            if (inf.AR_VALID && inf.AR_READY)
                next_state = READ_WAIT;
        end
        
        READ_WAIT: begin
            next_state = READ_DATA;
        end
        
        READ_DATA: begin
            if (inf.R_VALID && inf.R_READY)
                next_state = COMPUTE;
        end
        
        COMPUTE: begin
            if ((warning_message == No_Warn) || (warning_message == Saturation_Warn))
                next_state = WRITE_ADDR; 
            else
                next_state = OUTPUT;  // No_Warn, Saturation_Warn
        end
        
        WRITE_ADDR: begin
            if (inf.AW_VALID && inf.AW_READY)
                next_state = WRITE_DATA;
        end
        
        WRITE_DATA: begin
            if (inf.W_VALID && inf.W_READY)
                next_state = WRITE_RESP;
        end
        
        WRITE_RESP: begin
            if (inf.B_VALID && inf.B_READY)
                next_state = OUTPUT;
        end
        
        OUTPUT: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

//==============================================//
//          Computation Logic                  //
//==============================================//
always_comb begin
    // Default values
    updated_player = cur_player;
    operation_complete = 1;
    warning_message = No_Warn;
    
    if (state == COMPUTE) begin
        case (current_action)
            //==========================================
            // LOGIN
            //==========================================
            Login: begin
                Date last_date;
                int new_exp, new_mp;
                logic exp_sat, mp_sat;
                logic [4:0] last_month_days;
                
                last_date.M = cur_player.M;
                last_date.D = cur_player.D;

                case (last_date.M)
                    1, 3, 5, 7, 8, 10, 12: last_month_days = 31;
                    4, 6, 9, 11:           last_month_days = 30;
                    2:                     last_month_days = 28;
                    default:               last_month_days = 30;
                endcase

                
                if (((current_date.M == last_date.M) && (current_date.D == last_date.D + 1)) ||
                    ((last_date.D == last_month_days) && (current_date.D == 1) && (current_date.M == last_date.M + 1)) ||
                    ((last_date.M == 12) && (last_date.D == 31) && (current_date.M == 1) && (current_date.D == 1))) begin

                    new_exp = {2'b0, cur_player.Exp} + 18'd512;
                    new_mp  = {2'b0, cur_player.MP} + 18'd1024;
                    updated_player.Exp = (new_exp[17:16] != 2'b00) ? 16'hFFFF : new_exp[15:0];
                    updated_player.MP  = (new_mp[17:16] != 2'b00) ? 16'hFFFF : new_mp[15:0];
                    
                    if ((new_exp[17:16] != 2'b00) || (new_mp[17:16] != 2'b00)) begin
                        operation_complete = 0;
                        warning_message = Saturation_Warn;
                    end
                end
                else begin
                    updated_player.Exp = cur_player.Exp;
                    updated_player.MP = cur_player.MP;
                end
                
                updated_player.M = current_date.M;
                updated_player.D = current_date.D;
            end
            
            //==========================================
            // LEVEL UP
            //==========================================
            Level_Up: begin
                int exp_needed;
                Attribute delta[0:3];
                logic [16:0] delta_final[0:3];
                Attribute original[0:3];
                int indices[0:3];
                int i, j, temp_idx;
                Attribute temp_attr;
                logic [17:0] sum;
                //int new_val;
                logic any_sat[0:3];
                logic [17:0] new_mp, new_hp, new_atk, new_def;
                logic [16:0] delta_ext, quarter, delta_adj;

                // Check Exp requirement
                exp_needed = get_exp_needed(current_mode);
                
                if (cur_player.Exp < exp_needed) begin
                    operation_complete = 0;
                    warning_message = Exp_Warn;
                end
                else begin
                    // Calculate delta based on training type
                    case (current_train_type)
                        Type_A: begin
                            logic [17:0] sum_pair1, sum_pair2, sum_total;
                            logic [15:0] delta_value;
                            //logic [16:0] delta_adj;
                            
                            sum_pair1 = cur_player.MP + cur_player.HP;
                            sum_pair2 = cur_player.Attack + cur_player.Defense;
                            sum_total = sum_pair1 + sum_pair2;
                            delta_value = sum_total[17:3];

                             // Apply mode adjustment
                            delta_adj = apply_mode_adjustment(delta_value, current_mode);
                            
                            new_mp  = {1'b0, cur_player.MP} + delta_adj;
                            new_hp  = {1'b0, cur_player.HP} + delta_adj;
                            new_atk = {1'b0, cur_player.Attack} + delta_adj;
                            new_def = {1'b0, cur_player.Defense} + delta_adj;
                            
                            // Stage 6: Saturation check (inline, no function call)
                            updated_player.MP = (new_mp[17:16] != 2'b00) ? 16'hFFFF : new_mp[15:0];
                            updated_player.HP = (new_hp[17:16] != 2'b00) ? 16'hFFFF : new_hp[15:0];
                            updated_player.Attack = (new_atk[17:16] != 2'b00) ? 16'hFFFF : new_atk[15:0];
                            updated_player.Defense = (new_def[17:16] != 2'b00) ? 16'hFFFF : new_def[15:0];
                            
                            // Warning flag
                            if ((new_mp[17:16] != 2'b00) || (new_hp[17:16] != 2'b00) || 
                                (new_atk[17:16] != 2'b00) || (new_def[17:16] != 2'b00)) begin
                                operation_complete = 0;
                                warning_message = Saturation_Warn;
                            end

                        end
                        
                        Type_B: begin
                            // Sort attributes and calculate differences
                            original[0] = cur_player.MP;
                            original[1] = cur_player.HP;
                            original[2] = cur_player.Attack;
                            original[3] = cur_player.Defense;
                            
                            indices[0] = 0;
                            indices[1] = 1;
                            indices[2] = 2;
                            indices[3] = 3;
                            
                            // Bubble sort indices by attribute values (ascending)
                            for (i = 0; i < 3; i = i + 1) begin
                                for (j = 0; j < 3-i; j = j + 1) begin
                                    if (original[indices[j]] > original[indices[j+1]]) begin
                                        temp_idx = indices[j];
                                        indices[j] = indices[j+1];
                                        indices[j+1] = temp_idx;
                                    end
                                end
                            end

                            // Initialize deltas to 0
                            delta[0] = 0;
                            delta[1] = 0;
                            delta[2] = 0;
                            delta[3] = 0;
                            
                            // A0, A1, A2, A3 are sorted values (A0=smallest, A3=largest)
                            // Delta_A0 = A2 - A0, Delta_A1 = A3 - A1
                            delta[indices[0]] = original[indices[2]] - original[indices[0]];
                            delta[indices[1]] = original[indices[3]] - original[indices[1]];

                             // Apply mode adjustment
                            delta_final[0] = apply_mode_adjustment(delta[0], current_mode);
                            delta_final[1] = apply_mode_adjustment(delta[1], current_mode);
                            delta_final[2] = apply_mode_adjustment(delta[2], current_mode);
                            delta_final[3] = apply_mode_adjustment(delta[3], current_mode);

                            new_mp  = {1'b0, cur_player.MP} + delta_final[0];
                            new_hp  = {1'b0, cur_player.HP} + delta_final[1];
                            new_atk = {1'b0, cur_player.Attack} + delta_final[2];
                            new_def = {1'b0, cur_player.Defense} + delta_final[3];
                            
                            // Stage 6: Saturation check (inline, no function call)
                            updated_player.MP = (new_mp[17:16] != 2'b00) ? 16'hFFFF : new_mp[15:0];
                            updated_player.HP = (new_hp[17:16] != 2'b00) ? 16'hFFFF : new_hp[15:0];
                            updated_player.Attack = (new_atk[17:16] != 2'b00) ? 16'hFFFF : new_atk[15:0];
                            updated_player.Defense = (new_def[17:16] != 2'b00) ? 16'hFFFF : new_def[15:0];
                            
                            // Warning flag
                            if ((new_mp[17:16] != 2'b00) || (new_hp[17:16] != 2'b00) || 
                                (new_atk[17:16] != 2'b00) || (new_def[17:16] != 2'b00)) begin
                                operation_complete = 0;
                                warning_message = Saturation_Warn;
                            end
                        end
                        
                        Type_C: begin
                            // If attribute < 16383, delta = 16383 - attribute, else delta = 0
                            delta[0] = (cur_player.MP < 16383) ? (16383 - cur_player.MP) : 0;
                            delta[1] = (cur_player.HP < 16383) ? (16383 - cur_player.HP) : 0;
                            delta[2] = (cur_player.Attack < 16383) ? (16383 - cur_player.Attack) : 0;
                            delta[3] = (cur_player.Defense < 16383) ? (16383 - cur_player.Defense) : 0;
                             // Apply mode adjustment
                            delta_final[0] = apply_mode_adjustment(delta[0], current_mode);
                            delta_final[1] = apply_mode_adjustment(delta[1], current_mode);
                            delta_final[2] = apply_mode_adjustment(delta[2], current_mode);
                            delta_final[3] = apply_mode_adjustment(delta[3], current_mode);
                            
                            new_mp  = {1'b0, cur_player.MP} + delta_final[0];
                            new_hp  = {1'b0, cur_player.HP} + delta_final[1];
                            new_atk = {1'b0, cur_player.Attack} + delta_final[2];
                            new_def = {1'b0, cur_player.Defense} + delta_final[3];
                            
                            // Stage 6: Saturation check (inline, no function call)
                            updated_player.MP = (new_mp[17:16] != 2'b00) ? 16'hFFFF : new_mp[15:0];
                            updated_player.HP = (new_hp[17:16] != 2'b00) ? 16'hFFFF : new_hp[15:0];
                            updated_player.Attack = (new_atk[17:16] != 2'b00) ? 16'hFFFF : new_atk[15:0];
                            updated_player.Defense = (new_def[17:16] != 2'b00) ? 16'hFFFF : new_def[15:0];
                            
                            // Warning flag
                            if ((new_mp[17:16] != 2'b00) || (new_hp[17:16] != 2'b00) || 
                                (new_atk[17:16] != 2'b00) || (new_def[17:16] != 2'b00)) begin
                                operation_complete = 0;
                                warning_message = Saturation_Warn;
                            end
                        end
                        
                        Type_D: begin
                            int new_val0, new_val1, new_val2, new_val3;

                            new_val0 = 3000 + ((65535 - cur_player.MP) >> 4);
                            delta[0] = (new_val0 > 5047) ? 5047 : new_val0[15:0];

                            new_val1 = 3000 + ((65535 - cur_player.HP) >> 4);
                            delta[1] = (new_val1 > 5047) ? 5047 : new_val1[15:0];

                            new_val2 = 3000 + ((65535 - cur_player.Attack) >> 4);
                            delta[2] = (new_val2 > 5047) ? 5047 : new_val2[15:0];

                            new_val3 = 3000 + ((65535 - cur_player.Defense) >> 4);
                            delta[3] = (new_val3 > 5047) ? 5047 : new_val3[15:0];

                             // Apply mode adjustment
                            delta_final[0] = apply_mode_adjustment(delta[0], current_mode);
                            delta_final[1] = apply_mode_adjustment(delta[1], current_mode);
                            delta_final[2] = apply_mode_adjustment(delta[2], current_mode);
                            delta_final[3] = apply_mode_adjustment(delta[3], current_mode);

                            new_mp  = {1'b0, cur_player.MP} + delta_final[0];
                            new_hp  = {1'b0, cur_player.HP} + delta_final[1];
                            new_atk = {1'b0, cur_player.Attack} + delta_final[2];
                            new_def = {1'b0, cur_player.Defense} + delta_final[3];
                            
                            // Stage 6: Saturation check (inline, no function call)
                            updated_player.MP = (new_mp[17:16] != 2'b00) ? 16'hFFFF : new_mp[15:0];
                            updated_player.HP = (new_hp[17:16] != 2'b00) ? 16'hFFFF : new_hp[15:0];
                            updated_player.Attack = (new_atk[17:16] != 2'b00) ? 16'hFFFF : new_atk[15:0];
                            updated_player.Defense = (new_def[17:16] != 2'b00) ? 16'hFFFF : new_def[15:0];
                            
                            // Warning flag
                            if ((new_mp[17:16] != 2'b00) || (new_hp[17:16] != 2'b00) || 
                                (new_atk[17:16] != 2'b00) || (new_def[17:16] != 2'b00)) begin
                                operation_complete = 0;
                                warning_message = Saturation_Warn;
                            end
                        end
                    endcase
                end
            end
            
            //==========================================
            // BATTLE
            //==========================================
            Battle: begin
                int damage_to_player, damage_to_monster;
                int player_hp_temp, monster_hp_temp;
                int new_exp, new_mp, new_attack, new_defense, new_hp;
                logic any_sat;
                
                // Check HP requirement
                if (cur_player.HP == 0) begin
                    operation_complete = 0;
                    warning_message = HP_Warn;
                end else begin
                    // Calculate damage
                    damage_to_player = (monster_attr[0] > cur_player.Defense) ? 
                                      (monster_attr[0] - cur_player.Defense) : 0;
                    damage_to_monster = (cur_player.Attack > monster_attr[1]) ? 
                                       (cur_player.Attack - monster_attr[1]) : 0;
                    
                    // Calculate HP_temp
                    player_hp_temp = (damage_to_player > 0) ? 
                                    (cur_player.HP - damage_to_player) : cur_player.HP;
                    monster_hp_temp = (damage_to_monster > 0) ? 
                                     (monster_attr[2] - damage_to_monster) : monster_attr[2];
                    
                    any_sat = 0;
                    
                    // Determine result
                    if (player_hp_temp > 0 && monster_hp_temp <= 0) begin
                        // WIN

                        new_exp = {2'b0, cur_player.Exp} + 18'd2048;
                        new_mp  = {2'b0, cur_player.MP} + 18'd2048;
                        new_hp  = {2'b0, player_hp_temp[15:0]};
                        
                        // Parallel saturation (inline)
                        updated_player.Exp = (new_exp > 65535) ? 16'hFFFF : new_exp[15:0];
                        updated_player.MP  = (new_mp > 65535) ? 16'hFFFF : new_mp[15:0];
                        updated_player.HP  = (new_hp > 65535) ? 16'hFFFF : new_hp[15:0];
                        
                        // Parallel warning check
                        if ((new_exp > 65535) || (new_mp > 65535) || (new_hp > 65535)) begin
                            operation_complete = 0;
                            warning_message = Saturation_Warn;
                        end
                        
                    end else if (player_hp_temp <= 0) begin
                        // LOSS
                        new_exp     = {2'b0, cur_player.Exp} - 18'd2048;
                        new_attack  = {2'b0, cur_player.Attack} - 18'd2048;
                        new_defense = {2'b0, cur_player.Defense} - 18'd2048;
                        
                        updated_player.Exp     = (new_exp[17]) ? 16'h0000 : new_exp[15:0];
                        updated_player.Attack  = (new_attack[17]) ? 16'h0000 : new_attack[15:0];
                        updated_player.Defense = (new_defense[17]) ? 16'h0000 : new_defense[15:0];
                        updated_player.HP      = 16'h0000;

                        if (new_exp[17] || new_attack[17] || new_defense[17]) begin
                            operation_complete = 0;
                            warning_message = Saturation_Warn;
                        end
                    end
                    else begin
                        // TIE
                        new_hp = {2'b0, player_hp_temp[15:0]};
                        updated_player.HP = (new_hp > 65535) ? 16'hFFFF : new_hp[15:0];

                        if (new_hp > 65535) begin
                            operation_complete = 0;
                            warning_message = Saturation_Warn;
                        end
                    end
                end
            end
            
            //==========================================
            // USE SKILL
            //==========================================
            Use_Skill: begin
                Attribute s[0:3];
                Attribute temp;
                int total_mp_needed;
                int skills_used;
                int new_mp;
                
                // Copy inputs
                s[0] = skill_mp[0];
                s[1] = skill_mp[1];
                s[2] = skill_mp[2];
                s[3] = skill_mp[3];
                
                // Sorting network for 4 elements (5 compare-swaps)
                // Layer 1
                if (s[0] > s[1]) begin temp = s[0]; s[0] = s[1]; s[1] = temp; end
                if (s[2] > s[3]) begin temp = s[2]; s[2] = s[3]; s[3] = temp; end
                
                // Layer 2
                if (s[0] > s[2]) begin temp = s[0]; s[0] = s[2]; s[2] = temp; end
                if (s[1] > s[3]) begin temp = s[1]; s[1] = s[3]; s[3] = temp; end
                
                // Layer 3
                if (s[1] > s[2]) begin temp = s[1]; s[1] = s[2]; s[2] = temp; end

                total_mp_needed = 0;
                skills_used = 0;
                
                if (cur_player.MP >= s[0]) begin
                    total_mp_needed = s[0];
                    skills_used = 1;
                    
                    if (cur_player.MP >= total_mp_needed + s[1]) begin
                        total_mp_needed = total_mp_needed + s[1];
                        skills_used = 2;
                        
                        if (cur_player.MP >= total_mp_needed + s[2]) begin
                            total_mp_needed = total_mp_needed + s[2];
                            skills_used = 3;
                            
                            if (cur_player.MP >= total_mp_needed + s[3]) begin
                                total_mp_needed = total_mp_needed + s[3];
                                skills_used = 4;
                            end
                        end
                    end
                end
                
                // Check and update MP
                if (skills_used == 0) begin
                    operation_complete = 0;
                    warning_message = MP_Warn;
                end
                else begin
                    new_mp = {2'b0, cur_player.MP} - {2'b0, total_mp_needed[15:0]};
                    updated_player.MP = (new_mp[17]) ? 16'h0000 : new_mp[15:0];

                    if (new_mp[17]) begin
                        operation_complete = 0;
                        warning_message = Saturation_Warn;
                    end
                end
            end
            
            //==========================================
            // CHECK INACTIVE
            //==========================================
            Check_Inactive: begin
                int last_total_days, today_total_days;


                /*int days_diff_result;
                Date last_date;
                last_date.M = cur_player.M;
                last_date.D = cur_player.D;
                
                days_diff_result = date_diff(last_date, current_date);
                
                if (days_diff_result > 90) begin
                    operation_complete = 0;
                    warning_message = Date_Warn;
                end*/



                

                
                int ld_M, ld_D;
                int days_in_month [12];
                int i;
    
                days_in_month[0] = 31;
                days_in_month[1] = 28;
                days_in_month[2] = 31;
                days_in_month[3] = 30;
                days_in_month[4] = 31;
                days_in_month[5] = 30;
                days_in_month[6] = 31;
                days_in_month[7] = 31;
                days_in_month[8] = 30;
                days_in_month[9] = 31;
                days_in_month[10] = 30;
                days_in_month[11] = 31;
                ld_M = cur_player.M;
                ld_D = cur_player.D;

                last_total_days = 0;
                for (i = 1; i < ld_M; i = i + 1) begin
                    last_total_days = last_total_days + days_in_month[i-1];
                end
                last_total_days = last_total_days + ld_D;

                today_total_days = 0;
                for (i = 1; i < current_date.M; i = i + 1) begin
                    today_total_days = today_total_days + days_in_month[i-1];
                end
                today_total_days = today_total_days + current_date.D;
                
                if (today_total_days < last_total_days) begin
                    today_total_days = today_total_days + 365;
                end

                if (today_total_days - last_total_days > 90) begin
                    operation_complete = 0;
                    warning_message = Date_Warn;
                end
            end

        endcase
    end
end
//==============================================//
//                Functions                     //
//==============================================//
/*
function automatic int date_diff(input Date last_date, input Date today_date);
    int days_in_month [12];
    int last_total_days, today_total_days;
    int i;
    
    days_in_month[0] = 31;
    days_in_month[1] = 28;
    days_in_month[2] = 31;
    days_in_month[3] = 30;
    days_in_month[4] = 31;
    days_in_month[5] = 30;
    days_in_month[6] = 31;
    days_in_month[7] = 31;
    days_in_month[8] = 30;
    days_in_month[9] = 31;
    days_in_month[10] = 30;
    days_in_month[11] = 31;
    
    // Convert last_date to days
    last_total_days = 0;

    case (last_date.M)
        1:  last_total_days = 0;
        2:  last_total_days = 31;
        3:  last_total_days = 59;   // 31+28
        4:  last_total_days = 90;   // 31+28+31
        5:  last_total_days = 120;  // 31+28+31+30
        6:  last_total_days = 151;  // 31+28+31+30+31
        7:  last_total_days = 181;  // 31+28+31+30+31+30
        8:  last_total_days = 212;  // 31+28+31+30+31+30+31
        9:  last_total_days = 243;  // 31+28+31+30+31+30+31+31
        10: last_total_days = 273;  // 31+28+31+30+31+30+31+31+30
        11: last_total_days = 304;  // 31+28+31+30+31+30+31+31+30+31
        12: last_total_days = 334;  // 31+28+31+30+31+30+31+31+30+31+30
        default: last_total_days = 0;
    endcase
    for (i = 1; i < last_date.M; i = i + 1) begin
        last_total_days = last_total_days + days_in_month[i-1];
    end
    last_total_days = last_total_days + last_date.D;
    
    // Convert today_date to days
    today_total_days = 0;
    case (today_date.M)
        1:  today_total_days = 0;
        2:  today_total_days = 31;
        3:  today_total_days = 59;
        4:  today_total_days = 90;
        5:  today_total_days = 120;
        6:  today_total_days = 151;
        7:  today_total_days = 181;
        8:  today_total_days = 212;
        9:  today_total_days = 243;
        10: today_total_days = 273;
        11: today_total_days = 304;
        12: today_total_days = 334;
        default: today_total_days = 0;
    endcase
    for (i = 1; i < today_date.M; i = i + 1) begin
        today_total_days = today_total_days + days_in_month[i-1];
    end
    today_total_days = today_total_days + today_date.D;
    
    // Handle year wraparound
    if (today_total_days < last_total_days) begin
        today_total_days = today_total_days + 365;
    end
    
    return today_total_days - last_total_days;
endfunction*/

// Get experience needed for each mode
function automatic int get_exp_needed(input Mode mode);
    int result;
    case (mode)
        Easy:    result = 4095;
        Normal:  result = 16383;
        Hard:    result = 32767;
        default: result = 16383;
    endcase
    return result;
endfunction

/*function automatic logic [16:0] apply_mode_adjustment(input Attribute delta, input Mode mode);
    logic [16:0] temp;
    case (mode)
        Easy:    temp = delta - (delta >> 2);
        Normal:  temp = delta;
        Hard:    temp = delta + (delta >> 2);
        default: temp = delta;
    endcase
    return temp;
endfunction*/

function automatic logic [16:0] apply_mode_adjustment(input Attribute delta, input Mode mode);
    logic [16:0] delta_ext, quarter, result;
    
    delta_ext = {1'b0, delta};
    quarter = {3'b0, delta[15:2]};  // Shift right by 2
    
    // Compute all 3 options in parallel
    case (mode)
        Easy:    result = delta_ext - quarter;   // 0.75x
        Hard:    result = delta_ext + quarter;   // 1.25x
        default: result = delta_ext;              // 1.0x
    endcase
    
    return result;
endfunction

endmodule