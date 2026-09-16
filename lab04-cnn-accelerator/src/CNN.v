//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2025 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Yen-Yu Chen
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V 1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CNN(
    // Input Port
    clk,
    rst_n,
    in_valid,
    Image,
    Kernel_ch1,
    Kernel_ch2,
	Weight_Bias,
    task_number,
    mode,
    capacity_cost,
    // Output Port
    out_valid,
    out
    );

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter (You can't modify these parameters)
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

input           clk, rst_n, in_valid;
input   [31:0]  Image;
input   [31:0]  Kernel_ch1;
input   [31:0]  Kernel_ch2;
input   [31:0]  Weight_Bias;
input           task_number;
input   [1:0]   mode;
input   [3:0]   capacity_cost;
output  reg         out_valid;
output  reg [31:0]  out;


//---------------------------------------------------------------------
// STATE PARAMETER
//---------------------------------------------------------------------
// State definitions
parameter IDLE = 4'd0;
parameter INPUT = 4'd1;
parameter WAIT = 4'd2;
parameter CONV1 = 4'd3;
parameter CONV2 = 4'd4;
parameter ACT1 = 4'd5;
parameter FULLY1 = 4'd6;
parameter FULLY2 = 4'd7;
parameter SOFTMAX = 4'd8;
parameter OUTPUT = 4'd9;
parameter SUMPOUT = 4'd10;
parameter CAP = 4'd11;
parameter WAIT2 = 4'd12;
parameter CAP2 = 4'd13;

parameter IN_IDLE = 2'd0;
parameter IN_IMAGE1 = 2'd1;
parameter IN_IMAGE2 = 2'd2;

parameter W_IDLE = 3'd0;
parameter W_1 = 3'd1;
parameter W_BIAS1 = 3'd2;
parameter W_20 = 3'd3;
parameter W_21 = 3'd4;
parameter W_22 = 3'd5;
parameter W_BIAS2 = 3'd6;
parameter W_DONE = 3'd7;

//---------------------------------------------------------------------
// REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg next_out_valid;
reg [31:0] next_out;

// State machine
reg [3:0] state, next_state;
reg [1:0] in_state, next_in_state;
reg [2:0] w_state, next_w_state;
reg [6:0] count, next_count; //71
reg [5:0] image_count, next_image_count; //35
reg [5:0] w_count, next_w_count; //39
reg [6:0] lastcount;

reg [31:0] image0 [0:35];
reg [31:0] image1 [0:35];
reg [31:0] ker_11 [0:8];
reg [31:0] ker_12 [0:8];
reg [31:0] ker_21 [0:8];
reg [31:0] ker_22 [0:8];
reg refl, swish, tas;
reg [31:0] weight8 [0:4][0:7];
reg [31:0] bias1, bias2;
reg [31:0] weight5 [0:2][0:4];
reg [3:0] capacity;
reg [5:0] cost [0:3];

reg [31:0] sum31_a, sum31_b, sum31_c, sum31_z, next_sum31_a, next_sum31_b, next_sum31_c;
reg [31:0] sum32_a, sum32_b, sum32_c, sum32_z, next_sum32_a, next_sum32_b, next_sum32_c;
reg [31:0] sum33_a, sum33_b, sum33_c, sum33_z, next_sum33_a, next_sum33_b, next_sum33_c;
reg [31:0] sum9_z;

reg [31:0] pout_11 [0:35];
//reg [31:0] pout_12 [0:35];
reg [31:0] pout_21 [0:35];
//reg [31:0] pout_22 [0:35];
reg [31:0] maxpool [0:7];
reg [31:0] leaky [0:4];
reg [31:0] leaky_x;
reg [31:0] z [0:2];
reg [31:0] zsum;
reg done, empty, next_empty;
reg [31:0] temp [0:3];
reg [31:0] kernel [0:3];
reg a_no, b_no, c_no, d_no, ac_no;
reg [3:0] new_max_idx, max_idx;
reg [31:0] max_cnn, lastsum;

// fp calculation
reg [31:0] m1_a, m1_b, m1_z;
reg [31:0] m2_a, m2_b, m2_z;
reg [31:0] m3_a, m3_b, m3_z;
reg [31:0] m4_a, m4_b, m4_z;
reg [31:0] m5_a, m5_b, m5_z;
reg [31:0] m6_a, m6_b, m6_z;
reg [31:0] m7_a, m7_b, m7_z;
reg [31:0] m8_a, m8_b, m8_z;
reg [31:0] m9_a, m9_b, m9_z;
reg [31:0] add_a ,add_b, add_z;
reg [31:0] old_max, try, cmp_max, new_max;
reg [2:0] mp_idx;
reg win;
reg [31:0] x, ex1, ex0, ex2, ex3;
reg [31:0] add_c, add_d, add_z2;
reg [31:0] div_a, div_b, div_z;
reg [31:0] exp_a, exp_z;

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
            if(count == 8)
                next_state = WAIT;
            else
                next_state = INPUT;
        end
        WAIT: begin
            next_state = CONV1;
        end
        CONV1: begin
            if(count == 71) begin
                if (tas)
                    next_state = SUMPOUT;
                else
                    next_state = CONV2;
            end
            else if (count == 8 && ac_no && !done && tas)
                next_state = WAIT;
            else
                next_state = CONV1;
        end
        SUMPOUT: begin
            if(count == 9) begin
                if (done) begin
                    if (d_no)
                        next_state = IDLE;
                    //else if(ac_no)
                    //    next_state = CAP3;
                    else
                        next_state = CAP;
                end
                else begin
                    if (cost[1] > capacity && cost[3] > capacity)
                        next_state = CAP2;
                    else
                        next_state = WAIT;
                end
            end
            else
                next_state = SUMPOUT;
        end
        CONV2: begin
            if (count == 71)
                next_state = WAIT2;
            else
                next_state = CONV2;
        end
        WAIT2: next_state = ACT1;
        ACT1: begin
            if (count == 31) 
                next_state = FULLY1;
            else
                next_state = ACT1;
        end
        FULLY1: begin
            if (count == 6) 
                next_state = FULLY2;
            else 
                next_state = FULLY1;
        end
        FULLY2: begin
            if (count == 3) 
                next_state = SOFTMAX;
            else
                next_state = FULLY2;
        end
        SOFTMAX: begin
            if (count == 3) 
                next_state = OUTPUT;
            else
                next_state = SOFTMAX;
        end
        OUTPUT: begin
            if (count == 2) 
                next_state = IDLE;
            else
                next_state = OUTPUT;
        end
        CAP: begin
            if (count == 7 || (count == 3 && a_no))
                next_state = IDLE;
            else
                next_state = CAP;
        end
        CAP2: begin
            if (count == 2)
                next_state = IDLE;
            else
                next_state = CAP2;
        end
        default: next_state = IDLE;
    endcase
end

//image
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        in_state <= IN_IDLE;
    else
        in_state <= next_in_state;
end

always @(*) begin
    case (in_state)
        IN_IDLE: begin
            if (in_valid)
                next_in_state = IN_IMAGE1;
            else
                next_in_state = IN_IDLE;
        end
        IN_IMAGE1: begin
            if(image_count == 35) begin
                if (tas)
                    next_in_state = IN_IDLE;
                else
                    next_in_state = IN_IMAGE2;
            end
            else
                next_in_state = IN_IMAGE1;
        end
        IN_IMAGE2: begin
            if(image_count == 35)
                next_in_state = IN_IDLE;
            else
                next_in_state = IN_IMAGE2;
        end
        default: next_in_state = IN_IDLE;
    endcase
end

//weight
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        w_state <= W_IDLE;
    else
        w_state <= next_w_state;
end

always @(*) begin
    case (w_state)
        W_IDLE: begin
            if (in_valid)
                next_w_state = W_1;
            else
                next_w_state = W_IDLE;
        end
        W_1: begin
            if(w_count == 39)
                next_w_state = W_BIAS1;
            else
                next_w_state = W_1;
        end
        W_BIAS1:
            next_w_state = W_20;
        W_20: begin
            if(w_count == 4)
                next_w_state = W_21;
            else
                next_w_state = W_20;
        end
        W_21: begin
            if(w_count == 4) 
                next_w_state = W_22;
            else
                next_w_state = W_21;
        end
        W_22: begin
            if(w_count == 4)
                next_w_state = W_BIAS2;
            else
                next_w_state = W_22;
        end
        W_BIAS2:
            next_w_state = W_DONE;
        W_DONE: begin
            if (out_valid) 
                next_w_state = W_IDLE;
            else
                next_w_state = W_DONE;
        end
        default: next_w_state = W_IDLE;
    endcase
end
//---------------------------------------------------------------------
// INPUT & COUNTER
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        image_count <= 0;
    end
    else begin
        count <= next_count;
        image_count <= next_image_count;
        w_count <= next_w_count;
        lastcount <= count;
    end
end

always @(*) begin
    case (state)
        IDLE: begin
            if (in_valid) 
                next_count = 1;
            else
                next_count = 0;
        end
        INPUT:
            next_count = count + 1;
        WAIT: 
            next_count = 0;
        CONV1, CONV2: begin
            if (count == 71) 
                next_count = 0;
            else
                next_count = count + 1;
        end
        SUMPOUT: begin
            if (count == 9) 
                next_count = 0;
            else
                next_count = count + 1;
        end
        ACT1: begin
            if (count == 31) begin
                next_count = 0;
            end
            else begin
                if (swish && (count[1:0] == 0)) 
                    next_count = count + 2;
                else
                    next_count = count + 1;
            end
        end
        FULLY1: begin
            if(count == 6)
                next_count = 0;
            else
                next_count = count + 1;
        end
        FULLY2: begin
            if(count == 3)
                next_count = 0;
            else
                next_count = count + 1;
        end
        SOFTMAX: begin
            if (count == 3) 
                next_count = 0;
            else
                next_count = count + 1;
        end
        OUTPUT: begin
            if (count == 2) 
                next_count = 0;
            else
                next_count = count + 1;
        end
        CAP: begin
            if (count == 7) 
                next_count = 0;
            else
                next_count = count + 1;
        end
        CAP2: begin
            if (count == 2) 
                next_count = 0;
            else
                next_count = count + 1;
        end
        default: 
            next_count = 0;
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else if (in_valid && in_state == IN_IDLE) begin
        swish <= mode[0];
        refl <= mode[1];
        tas <= task_number;
        capacity <= capacity_cost;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == INPUT && tas) begin
            cost[count - 1] <= capacity_cost;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        case (state)
            IDLE: begin
                if (in_valid) begin
                    ker_11[0] <= Kernel_ch1;
                    ker_21[0] <= Kernel_ch2;
                end
            end
            INPUT: begin
                ker_11[count] <= Kernel_ch1;
                ker_21[count] <= Kernel_ch2;
            end
            WAIT: begin
                ker_12[0] <= Kernel_ch1;
                ker_22[0] <= Kernel_ch2;
            end
            CONV1: begin
                if(count < 8 && !done) begin
                    ker_12[count + 1] <= Kernel_ch1;
                    ker_22[count + 1] <= Kernel_ch2;
                end
                else if (count == 70 || (count == 8 && ac_no && !done && tas)) begin
                    for ( integer i = 0; i < 9; i = i + 1 ) begin
                        ker_11[i] <= ker_12[i];
                        ker_21[i] <= ker_22[i];
                    end
                end
            end       
        endcase
    end
end

//image
always @(*) begin
    next_image_count = 0;
    if (in_valid) begin
        if (image_count == 35)
            next_image_count = 0;
        else
            next_image_count = image_count + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        case (in_state)
            IN_IDLE: begin
                if (in_valid) begin
                    image0[0] <= Image;
                end
            end
            IN_IMAGE1: image0[image_count] <= Image;
            IN_IMAGE2: image1[image_count] <= Image;
        endcase
        if((count == 70) && state == CONV1 && !tas) begin
            for ( integer i = 0; i < 36 ; i = i + 1) begin
                image0[i] <= image1[i];
            end
        end
    end
end

//weight
always @(*) begin
    next_w_count = 0;
    case (w_state)
        W_IDLE: begin
            if (in_valid)
                next_w_count = 1;        
        end
        W_1: 
            next_w_count = w_count + 1;
        W_BIAS1:
            next_w_count = 0; 
        W_20, W_21, W_22: begin
            if (w_count == 4) 
                next_w_count = 0;
            else
                next_w_count = w_count + 1;
        end
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        case (w_state)
            W_IDLE: begin
                if (in_valid) 
                    weight8[0][0] <= Weight_Bias;
            end 
            W_1: 
                weight8[w_count[5:3]][w_count[2:0]] <= Weight_Bias;
            W_BIAS1:
                bias1 <= Weight_Bias;
            W_20: 
                weight5[0][w_count] <= Weight_Bias;
            W_21: 
                weight5[1][w_count] <= Weight_Bias;
            W_22: 
                weight5[2][w_count] <= Weight_Bias;
            W_BIAS2:
                bias2 <= Weight_Bias;
        endcase
    end
end

//---------------------------------------------------------------------
// MAIN LOGIC
//---------------------------------------------------------------------
assign a_no = (kernel[0][31] || (capacity < cost[0]));
assign b_no = (kernel[1][31] || (capacity < cost[1]));
assign c_no = (kernel[2][31] || (capacity < cost[2]));
assign d_no = (sum9_z[31] || (capacity < cost[3]));
assign ac_no = (capacity < cost[0] && capacity < cost[2]);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        sum31_a <= next_sum31_a;
        sum31_b <= next_sum31_b;
        sum31_c <= next_sum31_c;
        sum32_a <= next_sum32_a;
        sum32_b <= next_sum32_b;
        sum32_c <= next_sum32_c;
        sum33_a <= next_sum33_a;
        sum33_b <= next_sum33_b;
        sum33_c <= next_sum33_c;

        leaky_x <= sum9_z;
    end
end
wire [31:0] const_0_01 = 32'h3C23D70A;
always @(*) begin
    next_sum31_a = 0; next_sum31_b = 0; next_sum31_c = 0;
    next_sum32_a = 0; next_sum32_b = 0; next_sum32_c = 0;
    next_sum33_a = 0; next_sum33_b = 0; next_sum33_c = 0;   
    m1_a = 0; m2_a = 0; m3_a = 0;
    m4_a = 0; m5_a = 0; m6_a = 0;
    m7_a = 0; m8_a = 0; m9_a = 0;
    m1_b = 0; m2_b = 0; m3_b = 0;
    m4_b = 0; m5_b = 0; m6_b = 0;
    m7_b = 0; m8_b = 0; m9_b = 0;
    case (state)
        WAIT: begin
            if (refl) begin //reflection padding + convolution 1
                m1_a = image0[7]; m2_a = image0[6]; m3_a = image0[7];
                m4_a = image0[1]; m5_a = image0[0]; m6_a = image0[1];
                m7_a = image0[7]; m8_a = image0[6]; m9_a = image0[7];
            end
            else begin //replication padding + convolution 1
                m1_a = image0[0]; m2_a = image0[0]; m3_a = image0[1];
                m4_a = image0[0]; m5_a = image0[0]; m6_a = image0[1];
                m7_a = image0[6]; m8_a = image0[6]; m9_a = image0[7];
            end
            m1_b = ker_11[0]; m2_b = ker_11[1]; m3_b = ker_11[2];
            m4_b = ker_11[3]; m5_b = ker_11[4]; m6_b = ker_11[5];
            m7_b = ker_11[6]; m8_b = ker_11[7]; m9_b = ker_11[8];
            next_sum31_a = m1_z; next_sum31_b = m2_z; next_sum31_c = m3_z;
            next_sum32_a = m4_z; next_sum32_b = m5_z; next_sum32_c = m6_z;
            next_sum33_a = m7_z; next_sum33_b = m8_z; next_sum33_c = m9_z;
        end
        CONV1, CONV2: begin
            //m1_a ~ m9_a
            case (count[6:1] + count[0])
                6'd0, 6'd36: begin
                    if (refl) begin
                        m1_a = image0[7]; m2_a = image0[6]; m3_a = image0[7]; m4_a = image0[1];  m7_a = image0[7]; end
                    else begin
                        m1_a = image0[0]; m2_a = image0[0]; m3_a = image0[1]; m4_a = image0[0];  m7_a = image0[6]; end
                    m5_a = image0[0]; m6_a = image0[1]; 
                    m8_a = image0[6]; m9_a = image0[7];
                end
                6'd1: begin
                    if (refl) begin
                        m1_a = image0[6]; m2_a = image0[7]; m3_a = image0[8]; end
                    else begin
                        m1_a = image0[0]; m2_a = image0[1]; m3_a = image0[2]; end
                    m4_a = image0[0]; m5_a = image0[1]; m6_a = image0[2];
                    m7_a = image0[6]; m8_a = image0[7]; m9_a = image0[8];
                end
                6'd2: begin
                    if (refl) begin
                        m1_a = image0[7]; m2_a = image0[8]; m3_a = image0[9]; end
                    else begin
                        m1_a = image0[1]; m2_a = image0[2]; m3_a = image0[3]; end
                    m4_a = image0[1]; m5_a = image0[2]; m6_a = image0[3];
                    m7_a = image0[7]; m8_a = image0[8]; m9_a = image0[9];
                end
                6'd3: begin
                    if (refl) begin
                        m1_a = image0[8]; m2_a = image0[9]; m3_a = image0[10]; end
                    else begin
                        m1_a = image0[2]; m2_a = image0[3]; m3_a = image0[4]; end
                    m4_a = image0[2]; m5_a = image0[3]; m6_a = image0[4];
                    m7_a = image0[8]; m8_a = image0[9]; m9_a = image0[10];
                end
                6'd4: begin
                    if (refl) begin
                        m1_a = image0[9]; m2_a = image0[10]; m3_a = image0[11]; end
                    else begin
                        m1_a = image0[3]; m2_a = image0[4]; m3_a = image0[5]; end
                    m4_a = image0[3]; m5_a = image0[4]; m6_a = image0[5];
                    m7_a = image0[9]; m8_a = image0[10]; m9_a = image0[11];
                end
                6'd5: begin
                    if (refl) begin
                        m1_a = image0[10]; m2_a = image0[11]; m3_a = image0[10]; m6_a = image0[4];  m9_a = image0[10]; end
                    else begin
                        m1_a = image0[4]; m2_a = image0[5]; m3_a = image0[5]; m6_a = image0[5];  m9_a = image0[11]; end
                    m4_a = image0[4]; m5_a = image0[5]; 
                    m7_a = image0[10]; m8_a = image0[11];
                end
                6'd6: begin
                    if (refl) begin
                        m1_a = image0[1]; m4_a = image0[7]; m7_a = image0[13]; end
                    else begin
                        m1_a = image0[0]; m4_a = image0[6]; m7_a = image0[12]; end
                    m2_a = image0[0]; m5_a = image0[6]; m8_a = image0[12];
                    m3_a = image0[1]; m6_a = image0[7]; m9_a = image0[13];
                end
                6'd7: begin
                    m1_a = image0[0]; m2_a = image0[1]; m3_a = image0[2];
                    m4_a = image0[6]; m5_a = image0[7]; m6_a = image0[8];
                    m7_a = image0[12]; m8_a = image0[13]; m9_a = image0[14];
                end
                6'd8: begin
                    m1_a = image0[1]; m2_a = image0[2]; m3_a = image0[3];
                    m4_a = image0[7]; m5_a = image0[8]; m6_a = image0[9];
                    m7_a = image0[13]; m8_a = image0[14]; m9_a = image0[15];
                end
                6'd9: begin
                    m1_a = image0[2]; m2_a = image0[3]; m3_a = image0[4];
                    m4_a = image0[8]; m5_a = image0[9]; m6_a = image0[10];
                    m7_a = image0[14]; m8_a = image0[15]; m9_a = image0[16];
                end
                6'd10: begin
                    m1_a = image0[3]; m2_a = image0[4]; m3_a = image0[5];
                    m4_a = image0[9]; m5_a = image0[10]; m6_a = image0[11];
                    m7_a = image0[15]; m8_a = image0[16]; m9_a = image0[17];
                end
                6'd11: begin
                    if (refl) begin
                        m3_a = image0[4]; m6_a = image0[10]; m9_a = image0[16]; end
                    else begin
                        m3_a = image0[5]; m6_a = image0[11]; m9_a = image0[17]; end
                    m1_a = image0[4]; m4_a = image0[10]; m7_a = image0[16];
                    m2_a = image0[5]; m5_a = image0[11]; m8_a = image0[17];
                end
                6'd12: begin
                    if (refl) begin
                        m1_a = image0[7]; m4_a = image0[13]; m7_a = image0[19]; end
                    else begin
                        m1_a = image0[6]; m4_a = image0[12]; m7_a = image0[18]; end
                    m2_a = image0[6]; m5_a = image0[12]; m8_a = image0[18];
                    m3_a = image0[7]; m6_a = image0[13]; m9_a = image0[19];
                end
                6'd13: begin
                    m1_a = image0[6]; m2_a = image0[7]; m3_a = image0[8];
                    m4_a = image0[12]; m5_a = image0[13]; m6_a = image0[14];
                    m7_a = image0[18]; m8_a = image0[19]; m9_a = image0[20];
                end
                6'd14: begin
                    m1_a = image0[7]; m2_a = image0[8]; m3_a = image0[9];
                    m4_a = image0[13]; m5_a = image0[14]; m6_a = image0[15];
                    m7_a = image0[19]; m8_a = image0[20]; m9_a = image0[21];
                end
                6'd15: begin
                    m1_a = image0[8]; m2_a = image0[9]; m3_a = image0[10];
                    m4_a = image0[14]; m5_a = image0[15]; m6_a = image0[16];
                    m7_a = image0[20]; m8_a = image0[21]; m9_a = image0[22];
                end
                6'd16: begin
                    m1_a = image0[9]; m2_a = image0[10]; m3_a = image0[11];
                    m4_a = image0[15]; m5_a = image0[16]; m6_a = image0[17];
                    m7_a = image0[21]; m8_a = image0[22]; m9_a = image0[23];
                end
                6'd17: begin
                    if (refl) begin
                        m3_a = image0[10]; m6_a = image0[16]; m9_a = image0[22]; end
                    else begin
                        m3_a = image0[11]; m6_a = image0[17]; m9_a = image0[23]; end
                    m1_a = image0[10]; m4_a = image0[16]; m7_a = image0[22];
                    m2_a = image0[11]; m5_a = image0[17]; m8_a = image0[23];
                end
                6'd18: begin
                    if (refl) begin
                        m1_a = image0[13]; m4_a = image0[19]; m7_a = image0[25]; end
                    else begin
                        m1_a = image0[12]; m4_a = image0[18]; m7_a = image0[24]; end
                    m2_a = image0[12]; m5_a = image0[18]; m8_a = image0[24];
                    m3_a = image0[13]; m6_a = image0[19]; m9_a = image0[25];
                end
                6'd19: begin
                    m1_a = image0[12]; m2_a = image0[13]; m3_a = image0[14];
                    m4_a = image0[18]; m5_a = image0[19]; m6_a = image0[20];
                    m7_a = image0[24]; m8_a = image0[25]; m9_a = image0[26];
                end
                6'd20: begin
                    m1_a = image0[13]; m2_a = image0[14]; m3_a = image0[15];
                    m4_a = image0[19]; m5_a = image0[20]; m6_a = image0[21];
                    m7_a = image0[25]; m8_a = image0[26]; m9_a = image0[27];
                end
                6'd21: begin
                    m1_a = image0[14]; m2_a = image0[15]; m3_a = image0[16];
                    m4_a = image0[20]; m5_a = image0[21]; m6_a = image0[22];
                    m7_a = image0[26]; m8_a = image0[27]; m9_a = image0[28];
                end
                6'd22: begin
                    m1_a = image0[15]; m2_a = image0[16]; m3_a = image0[17];
                    m4_a = image0[21]; m5_a = image0[22]; m6_a = image0[23];
                    m7_a = image0[27]; m8_a = image0[28]; m9_a = image0[29];
                end
                6'd23: begin
                    if (refl) begin
                        m3_a = image0[16]; m6_a = image0[22]; m9_a = image0[28]; end
                    else begin
                        m3_a = image0[17]; m6_a = image0[23]; m9_a = image0[29]; end
                    m1_a = image0[16]; m4_a = image0[22]; m7_a = image0[28];
                    m2_a = image0[17]; m5_a = image0[23]; m8_a = image0[29];
                end
                6'd24: begin
                    if (refl) begin
                        m1_a = image0[19]; m4_a = image0[25]; m7_a = image0[31]; end
                    else begin
                        m1_a = image0[18]; m4_a = image0[24]; m7_a = image0[30]; end
                    m2_a = image0[18]; m5_a = image0[24]; m8_a = image0[30];
                    m3_a = image0[19]; m6_a = image0[25]; m9_a = image0[31];
                end
                6'd25: begin
                    m1_a = image0[18]; m2_a = image0[19]; m3_a = image0[20];
                    m4_a = image0[24]; m5_a = image0[25]; m6_a = image0[26];
                    m7_a = image0[30]; m8_a = image0[31]; m9_a = image0[32];
                end
                6'd26: begin
                    m1_a = image0[19]; m2_a = image0[20]; m3_a = image0[21];
                    m4_a = image0[25]; m5_a = image0[26]; m6_a = image0[27];
                    m7_a = image0[31]; m8_a = image0[32]; m9_a = image0[33];
                end
                6'd27: begin
                    m1_a = image0[20]; m2_a = image0[21]; m3_a = image0[22];
                    m4_a = image0[26]; m5_a = image0[27]; m6_a = image0[28];
                    m7_a = image0[32]; m8_a = image0[33]; m9_a = image0[34];
                end
                6'd28: begin
                    m1_a = image0[21]; m2_a = image0[22]; m3_a = image0[23];
                    m4_a = image0[27]; m5_a = image0[28]; m6_a = image0[29];
                    m7_a = image0[33]; m8_a = image0[34]; m9_a = image0[35];
                end
                6'd29: begin
                    if (refl) begin
                        m3_a = image0[22]; m6_a = image0[28]; m9_a = image0[34]; end
                    else begin
                        m3_a = image0[23]; m6_a = image0[29]; m9_a = image0[35]; end
                    m1_a = image0[22]; m4_a = image0[28]; m7_a = image0[34];
                    m2_a = image0[23]; m5_a = image0[29]; m8_a = image0[35];
                end
                6'd30: begin
                    if (refl) begin
                        m1_a = image0[25]; m4_a = image0[31]; m7_a = image0[25]; m8_a = image0[24];  m9_a = image0[25]; end
                    else begin
                        m1_a = image0[24]; m4_a = image0[30]; m7_a = image0[30]; m8_a = image0[30];  m9_a = image0[31]; end
                    m2_a = image0[24]; m3_a = image0[25]; 
                    m5_a = image0[30]; m6_a = image0[31];
                end
                6'd31: begin
                    if (refl) begin
                        m7_a = image0[24]; m8_a = image0[25]; m9_a = image0[26]; end
                    else begin
                        m7_a = image0[30]; m8_a = image0[31]; m9_a = image0[32]; end
                    m1_a = image0[24]; m2_a = image0[25]; m3_a = image0[26];
                    m4_a = image0[30]; m5_a = image0[31]; m6_a = image0[32];
                end
                6'd32: begin
                    if (refl) begin
                        m7_a = image0[25]; m8_a = image0[26]; m9_a = image0[27]; end
                    else begin
                        m7_a = image0[31]; m8_a = image0[32]; m9_a = image0[33]; end
                    m1_a = image0[25]; m2_a = image0[26]; m3_a = image0[27];
                    m4_a = image0[31]; m5_a = image0[32]; m6_a = image0[33];
                end
                6'd33: begin
                    if (refl) begin
                        m7_a = image0[26]; m8_a = image0[27]; m9_a = image0[28]; end
                    else begin
                        m7_a = image0[32]; m8_a = image0[33]; m9_a = image0[34]; end
                    m1_a = image0[26]; m2_a = image0[27]; m3_a = image0[28];
                    m4_a = image0[32]; m5_a = image0[33]; m6_a = image0[34];
                end
                6'd34: begin
                    if (refl) begin
                        m7_a = image0[27]; m8_a = image0[28]; m9_a = image0[29]; end
                    else begin
                        m7_a = image0[33]; m8_a = image0[34]; m9_a = image0[35]; end
                    m1_a = image0[27]; m2_a = image0[28]; m3_a = image0[29];
                    m4_a = image0[33]; m5_a = image0[34]; m6_a = image0[35];
                end
                6'd35: begin
                    if (refl) begin
                        m3_a = image0[28]; m6_a = image0[34]; m7_a = image0[28]; m8_a = image0[29];  m9_a = image0[28]; end
                    else begin
                        m3_a = image0[29]; m6_a = image0[35]; m7_a = image0[34]; m8_a = image0[35];  m9_a = image0[35]; end
                    m1_a = image0[28]; m2_a = image0[29]; 
                    m4_a = image0[34]; m5_a = image0[35];
                end
            endcase

            if (count[0]) begin
                m1_b = ker_11[0]; m2_b = ker_11[1]; m3_b = ker_11[2];
                m4_b = ker_11[3]; m5_b = ker_11[4]; m6_b = ker_11[5];
                m7_b = ker_11[6]; m8_b = ker_11[7]; m9_b = ker_11[8];
            end
            else begin
                m1_b = ker_21[0]; m2_b = ker_21[1]; m3_b = ker_21[2];
                m4_b = ker_21[3]; m5_b = ker_21[4]; m6_b = ker_21[5];
                m7_b = ker_21[6]; m8_b = ker_21[7]; m9_b = ker_21[8];
            end
            if (next_state == SUMPOUT) begin
                next_sum31_a = pout_11[0]; next_sum31_b = pout_11[1]; next_sum31_c = pout_11[2];
                next_sum32_a = pout_11[3]; next_sum32_b = pout_11[4]; next_sum32_c = pout_11[5];
                next_sum33_a = pout_11[6]; next_sum33_b = pout_11[7]; next_sum33_c = pout_11[8];
            end
            else begin
                next_sum31_a = m1_z; next_sum31_b = m2_z; next_sum31_c = m3_z;
                next_sum32_a = m4_z; next_sum32_b = m5_z; next_sum32_c = m6_z;
                next_sum33_a = m7_z; next_sum33_b = m8_z; next_sum33_c = m9_z;
            end
            
        end
        FULLY1: begin
            m1_a = maxpool[0]; m2_a = maxpool[1]; m3_a = maxpool[2]; m4_a = maxpool[3];
            m5_a = maxpool[4]; m6_a = maxpool[5]; m7_a = maxpool[6]; m8_a = maxpool[7];
            
            m1_b = weight8[count][0]; m2_b = weight8[count][1]; m3_b = weight8[count][2]; m4_b = weight8[count][3];
            m5_b = weight8[count][4]; m6_b = weight8[count][5]; m7_b = weight8[count][6]; m8_b = weight8[count][7];

            next_sum31_a = m1_z; next_sum31_b = m2_z; next_sum31_c = m3_z;
            next_sum32_a = m4_z; next_sum32_b = m5_z; next_sum32_c = m6_z;
            next_sum33_a = m7_z; next_sum33_b = m8_z; next_sum33_c = bias1;
            if (leaky_x[31]) begin // x < 0
                m9_a = leaky_x;
                m9_b = const_0_01;
                //3c23d70a 0011_1100_0010_0011_1101_0111_0000_1010 3C23D70A 0011_1100_0010_0011_1101_0111_0000_1010
            end
        end
        FULLY2: begin
            m1_a = leaky[0]; m2_a = leaky[1]; m3_a = leaky[2]; m4_a = leaky[3]; m5_a = leaky[4];
            m1_b = weight5[count][0]; m2_b = weight5[count][1]; m3_b = weight5[count][2]; m4_b = weight5[count][3]; m5_b = weight5[count][4]; 
            next_sum31_a = m1_z; next_sum31_b = m2_z; next_sum31_c = m3_z;
            next_sum32_a = m4_z; next_sum32_b = m5_z; next_sum32_c = bias2;
        end
        SOFTMAX: begin
            if (count == 2) begin
                next_sum33_a = z[0]; next_sum33_b = z[1]; next_sum33_c = exp_z;
            end
        end
        SUMPOUT: begin
            case (count)
                4'd0: begin
                    next_sum31_a = pout_11[9]; next_sum31_b = pout_11[10]; next_sum31_c = pout_11[11];
                    next_sum32_a = pout_11[12]; next_sum32_b = pout_11[13]; next_sum32_c = pout_11[14];
                    next_sum33_a = pout_11[15]; next_sum33_b = pout_11[16]; next_sum33_c = pout_11[17];
                end 
                4'd1: begin
                    next_sum31_a = pout_11[18]; next_sum31_b = pout_11[19]; next_sum31_c = pout_11[20];
                    next_sum32_a = pout_11[21]; next_sum32_b = pout_11[22]; next_sum32_c = pout_11[23];
                    next_sum33_a = pout_11[24]; next_sum33_b = pout_11[25]; next_sum33_c = pout_11[26];
                end 
                4'd2: begin
                    next_sum31_a = pout_11[27]; next_sum31_b = pout_11[28]; next_sum31_c = pout_11[29];
                    next_sum32_a = pout_11[30]; next_sum32_b = pout_11[31]; next_sum32_c = pout_11[32];
                    next_sum33_a = pout_11[33]; next_sum33_b = pout_11[34]; next_sum33_c = pout_11[35];
                end 
                4'd3: begin
                    next_sum31_a = temp[0]; next_sum31_b = temp[1];
                    next_sum32_a = temp[2]; next_sum32_b = sum9_z;
                end 
                4'd4: begin
                    next_sum31_a = pout_21[0]; next_sum31_b = pout_21[1]; next_sum31_c = pout_21[2];
                    next_sum32_a = pout_21[3]; next_sum32_b = pout_21[4]; next_sum32_c = pout_21[5];
                    next_sum33_a = pout_21[6]; next_sum33_b = pout_21[7]; next_sum33_c = pout_21[8];
                end
                4'd5: begin
                    next_sum31_a = pout_21[9]; next_sum31_b = pout_21[10]; next_sum31_c = pout_21[11];
                    next_sum32_a = pout_21[12]; next_sum32_b = pout_21[13]; next_sum32_c = pout_21[14];
                    next_sum33_a = pout_21[15]; next_sum33_b = pout_21[16]; next_sum33_c = pout_21[17];
                end 
                4'd6: begin
                    next_sum31_a = pout_21[18]; next_sum31_b = pout_21[19]; next_sum31_c = pout_21[20];
                    next_sum32_a = pout_21[21]; next_sum32_b = pout_21[22]; next_sum32_c = pout_21[23];
                    next_sum33_a = pout_21[24]; next_sum33_b = pout_21[25]; next_sum33_c = pout_21[26];
                end 
                4'd7: begin
                    next_sum31_a = pout_21[27]; next_sum31_b = pout_21[28]; next_sum31_c = pout_21[29];
                    next_sum32_a = pout_21[30]; next_sum32_b = pout_21[31]; next_sum32_c = pout_21[32];
                    next_sum33_a = pout_21[33]; next_sum33_b = pout_21[34]; next_sum33_c = pout_21[35];
                end 
                4'd8: begin
                    next_sum31_a = temp[0]; next_sum31_b = temp[1];
                    next_sum32_a = temp[2]; next_sum32_b = sum9_z;
                end
            endcase
        end

    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        case (state)
            IDLE: 
                done <= 0;
            CONV1: begin
                if (count == 8 && ac_no && tas)
                    done <= 1;
            end
            SUMPOUT: begin
                if (count == 9 && !done) begin
                    done <= 1;
                end
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        case (state)
            CONV1: begin
                if (count[0])
                    pout_21[count[6:1]] <= sum9_z;
                else
                    pout_11[count[6:1]] <= sum9_z;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == SUMPOUT) begin
            case (count)
                4'd0, 4'd5: temp[0] <= sum9_z;
                4'd1, 4'd6: temp[1] <= sum9_z;
                4'd2, 4'd7: temp[2] <= sum9_z;
                4'd3, 4'd8: temp[3] <= sum9_z;
                4'd4: begin
                    if (done) 
                        kernel[1] <= sum9_z;
                    else
                        kernel[0] <= sum9_z;
                end
                4'd9: begin
                    if (next_state == CAP) 
                        kernel[3] <= sum9_z;
                    else
                        kernel[2] <= sum9_z;
                end
            endcase
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == CONV2) begin
            maxpool[mp_idx] <= new_max;
        end
        else if (state == WAIT2) begin
            maxpool[7] <= new_max;
        end
        else if (state == ACT1 && count[1:0] == 3) begin
            maxpool[count[4:2]] <= div_z;
        end
    end
end
reg [4:0] flag;
always @(*) begin
    add_a = 0;
    add_b = 0;
    mp_idx = 0;
    old_max = 0;
    try = 0;
    new_max = max_cnn;
    new_max_idx = max_idx;
    next_empty = empty;
    case (state)
    CONV2: begin
        //pout1 + sum9_z = add_z (compare b)
        if (lastcount[0]) begin
            add_a = pout_21[lastcount[6:1]];
            add_b = leaky_x;
            //pout_22[lastcount[6:1]] <= sum9_z;
            if (lastcount[6:1] == 0) begin
                new_max = add_z;
                mp_idx = 4;
            end
            else if (lastcount[6:1] == 3) begin
                new_max = add_z;
                mp_idx = 5;
            end
            else if (lastcount[6:1] == 18) begin
               new_max = add_z;
               mp_idx = 6; 
            end
            else if (lastcount[6:1] == 21) begin
                new_max = add_z;
                mp_idx = 7;
            end
            else begin
                if ((lastcount[6:2] / 3) > 2) begin
                    if ((lastcount[6:1] % 6) > 2) begin
                        old_max = maxpool[7];
                        try = add_z;
                        mp_idx = 7;
                        new_max = cmp_max;
                    end
                    else begin
                        old_max = maxpool[6];
                        try = add_z;
                        mp_idx = 6;
                        new_max = cmp_max;
                    end
                end
                else begin
                    if ((lastcount[6:1] % 6) > 2) begin
                        old_max = maxpool[5];
                        try = add_z;
                        mp_idx = 5;
                        new_max = cmp_max;
                    end
                    else begin
                        old_max = maxpool[4];
                        try = add_z;
                        mp_idx = 4;
                        new_max = cmp_max;
                    end
                end
            end
        end
        else begin
            add_a = pout_11[lastcount[6:1]];
            add_b = leaky_x;
            //pout_12[lastcount[6:1]] <= sum9_z;
            if (lastcount[6:1] == 0) begin
                new_max = add_z;
                mp_idx = 0;
            end
            else if (lastcount[6:1] == 3) begin
                new_max = add_z;
                mp_idx = 1;
            end
            else if (lastcount[6:1] == 18) begin
               new_max = add_z;
               mp_idx = 2; 
            end
            else if (lastcount[6:1] == 21) begin
                new_max = add_z;
                mp_idx = 3;
            end
            else begin
                if ((lastcount[6:2] / 3) > 2) begin
                    if ((lastcount[6:1] % 6) > 2) begin
                        old_max = maxpool[3];
                        try = add_z;
                        mp_idx = 3;
                        new_max = cmp_max;
                    end
                    else begin
                        old_max = maxpool[2];
                        try = add_z;
                        mp_idx = 2;
                        new_max = cmp_max;
                    end
                end
                else begin
                    if ((lastcount[6:1] % 6) > 2) begin
                        old_max = maxpool[1];
                        try = add_z;
                        mp_idx = 1;
                        new_max = cmp_max;
                    end
                    else begin
                        old_max = maxpool[0];
                        try = add_z;
                        mp_idx = 0;
                        new_max = cmp_max;
                    end
                end
            end
        end
    end
    WAIT2: begin
        add_a = pout_21[35];
        add_b = leaky_x;
        old_max = maxpool[7];
        try = add_z;
        mp_idx = 7;
        new_max = cmp_max;
    end
    ACT1: begin
        if (count[1:0] == 2) begin
            add_b = ex1;
            if (swish) 
                add_a = 32'h3F800000;
            else
                add_a = ex0;
        end
    end
    SUMPOUT: begin
        if (done) begin
            case (count)
                4'd2 : begin //0010
                    if (c_no) begin
                        new_max_idx = 0;
                        next_empty = 1;
                    end
                    else begin
                        new_max = kernel[2];
                        new_max_idx = 2;
                        next_empty = 0;
                    end
                end
                4'd3: begin //1000
                    if (!a_no) begin
                        if (empty) begin
                            new_max = kernel[0];
                            new_max_idx = 8;
                            next_empty = 0;
                        end
                        else begin
                            old_max = max_cnn;
                            try = kernel[0];
                            new_max = cmp_max;
                            if (win)
                                new_max_idx = 8;
                        end
                    end
                end
                4'd4: begin //1010
                    if (!a_no && !c_no && (cost[0] + cost[2] <= capacity)) begin
                        add_a = kernel[0];
                        add_b = kernel[2];
                        old_max = max_cnn;
                        try = add_z;
                        new_max = cmp_max;
                        if (win)
                            new_max_idx = 10;
                    end
                end

                4'd5: begin //0100
                    if (!b_no) begin
                        if (empty) begin
                            new_max = kernel[1];
                            new_max_idx = 4;
                            next_empty = 0;
                        end
                        else begin
                            old_max = max_cnn;
                            try = kernel[1];
                            new_max = cmp_max;
                            if (win)
                                new_max_idx = 4;
                        end
                    end
                end
                4'd6: begin //0110
                    if (!b_no && !c_no && (cost[1] + cost[2] <= capacity)) begin
                        add_a = kernel[1];
                        add_b = kernel[2];
                        old_max = max_cnn;
                        try = add_z;
                        new_max = cmp_max;
                        if (win)
                            new_max_idx = 6;
                    end
                end
                4'd7: begin //1100
                    if (!a_no && !b_no && (cost[0] + cost[1] <= capacity)) begin
                        add_a = kernel[0];
                        add_b = kernel[1];
                        old_max = max_cnn;
                        try = add_z;
                        new_max = cmp_max;
                        if (win)
                            new_max_idx = 12;
                    end
                end
                4'd8: begin //1110
                    if (!a_no && !b_no && !c_no && (cost[0] + cost[1] + cost[2] <= capacity)) begin
                        add_a = lastsum;
                        add_b = kernel[2];
                        old_max = max_cnn;
                        try = add_z;
                        new_max = cmp_max;
                        if (win)
                            new_max_idx = 14;
                    end
                end
            endcase
        end
    end
    CAP: begin
        case (count)
            4'd0: begin // 0001
                if (empty) begin
                    new_max = kernel[3];
                    new_max_idx = 1;
                    next_empty = 0;
                end
                else begin
                    old_max = max_cnn;
                    try = kernel[3];
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 1;
                end
            end 
            4'd1: begin // 0011
                if (!c_no && ((cost[2] + cost[3]) <= capacity)) begin
                    flag = cost[2] + cost[3];
                    add_a = kernel[2];
                    add_b = kernel[3];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 3;
                end
            end
            4'd2: begin // 0111
                if (!b_no && !c_no && (cost[1] + cost[2] + cost[3] <= capacity)) begin
                    add_a = lastsum;
                    add_b = kernel[1];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 7;
                end
            end
            4'd3: begin // 0101
                if (!b_no && (cost[1] + cost[3] <= capacity)) begin
                    add_a = kernel[1];
                    add_b = kernel[3];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 5;
                end
            end
            4'd4: begin //1101
                if (!a_no && !b_no && (cost[0] + cost[1] + cost[3] <= capacity)) begin
                    add_a = lastsum;
                    add_b = kernel[0];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 13;
                end
            end
            4'd5: begin // 1001
                if (!a_no && (cost[0] + cost[3] <= capacity)) begin
                    add_a = kernel[0];
                    add_b = kernel[3];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 9;
                end
            end
            4'd6: begin // 1011
                if (!a_no && !c_no && (cost[0] + cost[2] + cost[3] <= capacity)) begin
                    add_a = lastsum;
                    add_b = kernel[2];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 11;
                end
            end
            4'd7: begin // 1111
                if (!a_no && !b_no && !c_no && (cost[0] + cost[1] + cost[2] + cost[3] <= capacity)) begin
                    add_a = lastsum;
                    add_b = kernel[1];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 15;
                end
            end
        endcase
    end
    CAP2: begin
        case (count)
            2'd0 : begin //0010
                if (c_no) begin
                    new_max_idx = 0;
                    next_empty = 1;
                end
                else begin
                    new_max = kernel[2];
                    new_max_idx = 2;
                    next_empty = 0;
                end
            end
            2'd1: begin //1000
                if (!a_no) begin
                    if (empty) begin
                        new_max = kernel[0];
                        new_max_idx = 8;
                        next_empty = 0;
                    end
                    else begin
                        old_max = max_cnn;
                        try = kernel[0];
                        new_max = cmp_max;
                        if (win)
                            new_max_idx = 8;
                    end
                end
            end
            2'd2: begin //1010
                if (!a_no && !c_no && (cost[0] + cost[2] <= capacity)) begin
                    add_a = kernel[0];
                    add_b = kernel[2];
                    old_max = max_cnn;
                    try = add_z;
                    new_max = cmp_max;
                    if (win)
                        new_max_idx = 10;
                end
            end
        endcase
    end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == SUMPOUT || state == CAP || state == CAP2) begin
            max_cnn <= new_max;
            max_idx <= new_max_idx;
            empty <= next_empty;
            lastsum <= add_z;
        end
    end
end

always @(*) begin
    x = 0;
    exp_a = 0;
    add_c = 0;
    add_d = 0;
    div_a = 0;
    div_b = 0;
    case (state)
        ACT1: begin
            x = maxpool[count[4:2]];
            case (count[1:0])
                2'd0: begin //e^(-x)   
                    exp_a = {~x[31], x[30:0]};
                end 
                2'd1: begin //e^x
                    exp_a = x;
                end
                2'd2: begin //+, -
                    if (!swish) begin
                        add_c = ex0;
                        add_d = {~ex1[31], ex1[30:0]};
                    end
                end
                2'd3: begin
                    div_a = ex3;
                    div_b = ex2;
                end
            endcase
        end
        SOFTMAX: begin
            exp_a = z[count];
        end
        OUTPUT: begin
            case (count)
                2'd0: begin
                    div_a = z[0];
                    div_b = zsum;
                end 
                2'd1: begin
                    div_a = z[1];
                    div_b = zsum;
                end 
                2'd2: begin
                    div_a = z[2];
                    div_b = zsum;
                end 
            endcase
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == ACT1) begin
            case (count[1:0])
                2'd0: 
                    ex1 <= exp_z;
                2'd1:
                    ex0 <= exp_z;
                2'd2: begin
                    ex2 <= add_z;
                    if (swish) 
                        ex3 <= x;
                    else
                        ex3 <= add_z2;
                end
            endcase
        end
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == FULLY1) begin
            if (leaky_x[31]) 
                leaky[count - 2] <= m9_z;
            else
                leaky[count - 2] <= leaky_x;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == FULLY2) begin
            case (count)
                2'd1: z[0] <= sum9_z;
                2'd2: z[1] <= sum9_z;
                2'd3: z[2] <= sum9_z;
            endcase
        end
        else if (state == SOFTMAX) begin
            case (count)
                2'd0: z[0] <= exp_z;
                2'd1: z[1] <= exp_z;
                2'd2: z[2] <= exp_z;
            endcase
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        
    end
    else begin
        if (state == SOFTMAX && count == 3) begin
            zsum <= sum33_z;
        end
    end
end



//---------------------------------------------------------------------
// OUTPUT
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out <= 0;
    end
    else begin
        out_valid <= next_out_valid;
        out <= next_out;
    end
end

always @(*) begin
    next_out_valid = 0;
    next_out = 0;
    if (state == OUTPUT) begin
        next_out = div_z;
        next_out_valid = 1;
    end
    //if ((state == CAP && count == 7) || (state == SUMPOUT && next_state == IDLE) || (state == CAP2 && )) begin
    if ((next_state == IDLE) && (state == CAP || state == CAP2 || state == SUMPOUT)) begin
        next_out = {28'b0, new_max_idx};
        next_out_valid = 1;
    end
end

//---------------------------------------------------------------------
//  fp
//---------------------------------------------------------------------
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    Umult1 ( .a(m1_a), .b(m1_b), .rnd(3'b000), .z(m1_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult2 ( .a(m2_a), .b(m2_b), .rnd(3'b000), .z(m2_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult3 ( .a(m3_a), .b(m3_b), .rnd(3'b000), .z(m3_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult4 ( .a(m4_a), .b(m4_b), .rnd(3'b000), .z(m4_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    Umult5 ( .a(m5_a), .b(m5_b), .rnd(3'b000), .z(m5_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult6 ( .a(m6_a), .b(m6_b), .rnd(3'b000), .z(m6_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult7 ( .a(m7_a), .b(m7_b), .rnd(3'b000), .z(m7_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult8 ( .a(m8_a), .b(m8_b), .rnd(3'b000), .z(m8_z), .status() );
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Umult9 ( .a(m9_a), .b(m9_b), .rnd(3'b000), .z(m9_z), .status() );

DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    Usum31 ( .a(sum31_a), .b(sum31_b), .c(sum31_c), .rnd(3'b000), .z(sum31_z), .status() );
DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    Usum32 ( .a(sum32_a), .b(sum32_b), .c(sum32_c), .rnd(3'b000), .z(sum32_z), .status() );
DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    Usum33 ( .a(sum33_a), .b(sum33_b), .c(sum33_c), .rnd(3'b000), .z(sum33_z), .status() );
DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
    Usum34 ( .a(sum31_z), .b(sum32_z), .c(sum33_z), .rnd(3'b000), .z(sum9_z), .status() );



DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Uadd1 ( .a(add_a), .b(add_b), .rnd(3'b000), .z(add_z), .status() );
    
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Uadd2 ( .a(add_c), .b(add_d), .rnd(3'b000), .z(add_z2), .status() );

DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    Ucmp1 ( .a(old_max), .b(try), .zctr(0), .aeqb(), .altb(win), .agtb(), .unordered(),
        .z0(), .z1(cmp_max), .status0(), .status1() );


DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch)
    Uexp1 ( .a(exp_a), .z(exp_z), .status() );

DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round) 
    Udiv1 ( .a(div_a), .b(div_b), .rnd(3'b000), .z(div_z), .status());
endmodule
