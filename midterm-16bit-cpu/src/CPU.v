//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Yen-Yu Chen
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CPU(

				clk,
			  rst_n,
  
		   IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);
// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/



// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf;
output  wire [WRIT_NUMBER-1:0]                awvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                awready_m_inf;
// axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf;
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf;
output  wire [WRIT_NUMBER-1:0]                 wvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf;
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf;
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf;
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf;
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf;
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf;
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf;
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf;
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf;
input   wire [DRAM_NUMBER-1:0]               arready_m_inf;
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;
// -----------------------------

//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/

reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;


//###########################################
//
// Wrtie down your design below
//
//###########################################

//####################################################
//               reg & wire
//####################################################

reg [3:0] state, next_state;
reg [15:0] pc, pc_next;
reg [15:0] current_instruction;

//Cache
reg [15:0] cache_base_inst, cache_base_inst_last;
reg [15:0] cache_base_data, cache_base_data_last;
reg cache_valid_inst;
reg cache_valid_data;

//reg [6:0] cache_offset_inst;
//reg [6:0] cache_offset_data;
reg [6:0] cache_offset;

reg cache_hit_inst;
reg cache_hit_data;
reg [15:0] miss_dram_addr;

reg [6:0] cache_fill_counter;


// SRAM Interface
reg [7:0] sram_addr;
reg [15:0] sram_di;
wire [15:0] sram_do;
reg sram_web;
reg sram_oe;
reg sram_cs;
reg [15:0] sram_do2;

// Instruction Decode
wire [2:0] opcode;
wire [3:0] rs, rt, rd;
wire [4:0] immediate;
wire [12:0] jump_addr;
wire func_bit;

// Data path
reg signed [15:0] data_addr, data_addr_next;
reg signed [15:0] reg_rs_data, reg_rt_data;

reg flag, next_flag, flag2;
reg [15:0] alu_result, alu_result_next;

//####################################################
//               state
//####################################################
parameter IDLE = 4'd0;
parameter INST_FETCH = 4'd1;
parameter INST_MISS_ADDR = 4'd2;
parameter INST_MISS_DATA = 4'd3;
parameter INST_DECODE = 4'd4;
parameter INST_EXE = 4'd5;
parameter DATA_ACCESS = 4'd6;
parameter R_EXE = 4'd13;
parameter DATA_MISS_ADDR = 4'd7;
parameter DATA_MISS_DATA = 4'd8;
parameter CAL_ADDR = 4'd12;
parameter STORE_ADDR = 4'd9;
parameter STORE_DATA = 4'd10;
parameter STORE_RESP = 4'd11;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: 
            next_state = INST_FETCH;
        INST_FETCH: begin
            if(cache_hit_inst)
                next_state = INST_DECODE;
            else
                next_state = INST_MISS_ADDR;
        end
        INST_MISS_ADDR: begin // send AXI read address
            if(arready_m_inf[1])
                next_state = INST_MISS_DATA;
        end
        INST_MISS_DATA: begin // wait for AXI read data
            if(rvalid_m_inf[1] && rlast_m_inf[1])
                next_state = INST_EXE;
        end

        INST_DECODE: begin
            next_state = INST_EXE; // decode from cache
        end
        INST_EXE: begin
            if (opcode[1])  // load store
                next_state = DATA_ACCESS;
            else
                next_state = R_EXE;
        end
        R_EXE:
            next_state = INST_FETCH;

        DATA_ACCESS: begin 
            if (opcode[0]) begin // 011 load
                if(cache_hit_data)
                    next_state = INST_FETCH;
                else
                    next_state = DATA_MISS_ADDR;
            end
            else begin //010 store
                if(cache_hit_data)
                    next_state = CAL_ADDR;
                else
                    next_state = DATA_MISS_ADDR;
            end
        end
        DATA_MISS_ADDR: begin
            if(arready_m_inf[0])
                next_state = DATA_MISS_DATA;
        end
        DATA_MISS_DATA: begin
            if(rvalid_m_inf[0] && rlast_m_inf[0])
                next_state = DATA_ACCESS;
        end
        CAL_ADDR:
            next_state = STORE_ADDR;
        STORE_ADDR: begin
            if(awready_m_inf)
                next_state = STORE_DATA;
        end
        STORE_DATA: begin
            if(wready_m_inf)
                next_state = STORE_RESP;
        end
        STORE_RESP: begin
            if(bvalid_m_inf)
                next_state = INST_FETCH;
        end
    endcase
end



//####################################################
//               Instruction Decode
//####################################################
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        current_instruction <= 0;
    else begin
        if (state == INST_MISS_DATA && rvalid_m_inf[1] && (cache_fill_counter == cache_offset)) begin
            current_instruction <= rdata_m_inf[31:16];
        end
        else if(state == INST_DECODE)
            current_instruction <= sram_do;
    end
end


assign opcode = current_instruction[15:13];
assign rs = current_instruction[12:9];
assign rt = current_instruction[8:5];
assign rd = current_instruction[4:1];
assign func_bit = current_instruction[0];
assign immediate = current_instruction[4:0];
assign jump_addr = current_instruction[12:0];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_addr <= 0;
    end
    else begin
        data_addr <= data_addr_next;
    end
end

wire [15:0] offset_inst = pc - cache_base_inst;
wire [15:0] offset_data = data_addr - cache_base_data;
wire [15:0] temp = {(reg_rs_data + $signed(immediate)), 1'b0};

always @(*) begin
    // sign(rs + immediate) × 2 + offset
    if(state == INST_EXE)
        data_addr_next =  temp + 16'h1000;
    else
        data_addr_next = data_addr;

    cache_hit_inst = cache_valid_inst && ~(|offset_inst[15:7]); // Checks if offset <= 127
    cache_hit_data = cache_valid_data && ~(|offset_data[15:7]);

    case (state)
        INST_FETCH, INST_DECODE, INST_MISS_ADDR, INST_MISS_DATA, INST_EXE: 
            cache_offset = offset_inst[7:1];
        DATA_ACCESS, DATA_MISS_ADDR, DATA_MISS_DATA: 
            cache_offset = offset_data[7:1];
        default: 
            cache_offset = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        miss_dram_addr <= 16'h1000;
        cache_fill_counter <= 0;
    end
    else begin
        case (state)
            INST_FETCH: begin
                if (!cache_hit_inst) begin
                    miss_dram_addr <= pc;
                    cache_fill_counter <= 0;
                end
            end
            INST_MISS_DATA: begin
                if(rvalid_m_inf[1] && !rlast_m_inf[1])
                    cache_fill_counter <= cache_fill_counter + 1;
            end

            DATA_ACCESS: begin
                if (!cache_hit_data) begin
                    miss_dram_addr <= data_addr;
                    cache_fill_counter <= 0;
                end
            end
            DATA_MISS_DATA: begin
                if(rvalid_m_inf[0] && !rlast_m_inf[0])
                    cache_fill_counter <= cache_fill_counter + 1;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cache_valid_inst <= 0;
        cache_valid_data <= 0;
    end
    else begin
        if(state == INST_MISS_DATA && rvalid_m_inf[1] && rlast_m_inf[1]) begin
            cache_valid_inst <= 1;
        end
        if (state == DATA_MISS_DATA && rvalid_m_inf[0] && rlast_m_inf[0]) begin
            cache_valid_data <= 1;
        end
            
    end
end

always @(*) begin
    if (state == DATA_MISS_ADDR) begin
        if(miss_dram_addr > 16'h1040)
            cache_base_data = miss_dram_addr - 64;
        else
            cache_base_data = 16'h1000;
    end
    else
        cache_base_data = cache_base_data_last;

    if (state == INST_MISS_ADDR) begin
        if(miss_dram_addr > 16'h1040) // 16'h1000 + 63
            cache_base_inst = miss_dram_addr - 64;
        else
            cache_base_inst = 16'h1000;
    end
    else
        cache_base_inst = cache_base_inst_last;

end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cache_base_inst_last <= 0;
        cache_base_data_last <= 0;
    end
    else begin
        cache_base_inst_last <= cache_base_inst;
        cache_base_data_last <= cache_base_data;
    end
end

//####################################################
//               Instruction EXE
//####################################################
reg IO_next;
reg eq, eq_next;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pc <= 16'h1000;
        eq <= 0;
    end
    else begin
        pc <= pc_next;
        eq <= eq_next;
    end
end
always @(*) begin
    eq_next = (reg_rs_data == reg_rt_data);
end
always @(*) begin
    pc_next = pc;
    if (state == R_EXE) begin
        case (opcode)
            3'b000, 3'b001: begin
                pc_next = pc + 2;
            end
            3'b101: begin // branch on equal
                if(eq) begin
                    pc_next = $signed(pc) + 2 + ($signed(immediate) << 1);
                end
                else begin
                    pc_next = pc + 2;
                end
            end
            3'b100: begin
                pc_next = jump_addr;
            end
        endcase
    end
    else if (next_flag || (state == STORE_RESP && bvalid_m_inf)) begin
        pc_next = pc + 2;
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        IO_stall <= 1;
    else 
        IO_stall <= IO_next;
end
always @(*) begin
    IO_next = 1;
    if ( (state == R_EXE) || flag2 || (state == STORE_RESP && bvalid_m_inf)) 
    
    //if ((state == INST_EXE && opcode[2] && !opcode[1]) || (state == R_EXE) || flag || (state == STORE_RESP && bvalid_m_inf)) 
        IO_next = 0;
end


//####################################################
//               Register Read Write
//####################################################

always @(*) begin
    case (rs)
        4'h0: reg_rs_data = core_r0;   4'h1: reg_rs_data = core_r1;
        4'h2: reg_rs_data = core_r2;   4'h3: reg_rs_data = core_r3;
        4'h4: reg_rs_data = core_r4;   4'h5: reg_rs_data = core_r5;
        4'h6: reg_rs_data = core_r6;   4'h7: reg_rs_data = core_r7;
        4'h8: reg_rs_data = core_r8;   4'h9: reg_rs_data = core_r9;
        4'hA: reg_rs_data = core_r10;  4'hB: reg_rs_data = core_r11;
        4'hC: reg_rs_data = core_r12;  4'hD: reg_rs_data = core_r13;
        4'hE: reg_rs_data = core_r14;  4'hF: reg_rs_data = core_r15;
    endcase

    case (rt)
        4'h0: reg_rt_data = core_r0;   4'h1: reg_rt_data = core_r1;
        4'h2: reg_rt_data = core_r2;   4'h3: reg_rt_data = core_r3;
        4'h4: reg_rt_data = core_r4;   4'h5: reg_rt_data = core_r5;
        4'h6: reg_rt_data = core_r6;   4'h7: reg_rt_data = core_r7;
        4'h8: reg_rt_data = core_r8;   4'h9: reg_rt_data = core_r9;
        4'hA: reg_rt_data = core_r10;  4'hB: reg_rt_data = core_r11;
        4'hC: reg_rt_data = core_r12;  4'hD: reg_rt_data = core_r13;
        4'hE: reg_rt_data = core_r14;  4'hF: reg_rt_data = core_r15;
    endcase
end

reg [7:0] p0, p1, p2, p4, p5, p6, p8, p9, p12;
reg signed [7:0] p3;

wire [7:0] p0_next = reg_rs_data[3:0] * reg_rt_data[3:0];
wire [7:0] p1_next = reg_rs_data[7:4] * reg_rt_data[3:0];
wire [7:0] p2_next = reg_rs_data[11:8] * reg_rt_data[3:0];
wire signed [7:0] p3_next = reg_rs_data[15:12] * reg_rt_data[3:0];

wire [7:0] p4_next = reg_rs_data[3:0] * reg_rt_data[7:4];
wire [7:0] p5_next = reg_rs_data[7:4] * reg_rt_data[7:4];
wire [7:0] p6_next = reg_rs_data[11:8] * reg_rt_data[7:4];

wire [7:0] p8_next = reg_rs_data[3:0] * reg_rt_data[11:8];
wire [7:0] p9_next = reg_rs_data[7:4] * reg_rt_data[11:8];

wire [7:0] p12_next = reg_rs_data[3:0] * reg_rt_data[15:12];

wire [3:0] product_a = p3[3:0] + p6[3:0] + p9[3:0] + p12[3:0];
wire [7:0] product_b = p2 + p5 + p8;
wire [8:0] product_c = p1 + p4;
//wire [15:0] product = {product_a, 12'b0} + {product_b, 8'b0} + {product_c, 4'b0} + p0;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        p0 <= 0; p1 <= 0; p2 <= 0; p3 <= 0; p4 <= 0;
        p5 <= 0; p6 <= 0; p8 <= 0; p9 <= 0; p12 <= 0;
        sram_do2 <= 0;
    end
    else begin
        p0 <= p0_next; p1 <= p1_next; p2 <= p2_next; p3 <= p3_next; p4 <= p4_next;
        p5 <= p5_next; p6 <= p6_next; p8 <= p8_next; p9 <= p9_next; p12 <= p12_next;
        sram_do2 <= sram_do;
    end
end

reg signed [15:0] r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        core_r0 <=  16'd0;  core_r1 <= 16'd0;  core_r2 <= 16'd0;   core_r3 <= 16'd0;
        core_r4 <=  16'd0;  core_r5 <= 16'd0;  core_r6 <= 16'd0;   core_r7 <= 16'h0;
        core_r8 <=  16'd0;  core_r9 <= 16'h0;  core_r10 <= 16'd0; core_r11 <= 16'd0;
        core_r12 <= 16'd0; core_r13 <= 16'd0;  core_r14 <= 16'd0; core_r15 <= 16'd0;
    end
    else begin
        core_r0  <= r0;
        core_r1  <= r1;
        core_r2  <= r2;
        core_r3  <= r3;
        core_r4  <= r4;
        core_r5  <= r5;
        core_r6  <= r6;
        core_r7  <= r7;
        core_r8  <= r8;
        core_r9  <= r9;
        core_r10 <= r10;
        core_r11 <= r11;
        core_r12 <= r12;
        core_r13 <= r13;
        core_r14 <= r14;
        core_r15 <= r15;
    end
end



always @(*) begin
    r0 = core_r0;
    r1 = core_r1;
    r2 = core_r2;
    r3 = core_r3;
    r4 = core_r4;
    r5 = core_r5;
    r6 = core_r6;
    r7 = core_r7;    
    r8 = core_r8;
    r9 = core_r9;
    r10 = core_r10;
    r11 = core_r11;
    r12 = core_r12;
    r13 = core_r13;
    r14 = core_r14;
    r15 = core_r15;
    //ADD, SUB, SLT, MULT
    if (state == R_EXE && !opcode[2]) begin// && !opcode[1]) begin
        if (!opcode[1] && opcode[0] && !func_bit) begin
            case (rd)
                4'h0: r0 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h1: r1 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h2: r2 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h3: r3 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h4: r4 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h5: r5 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h6: r6 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h7: r7 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h8: r8 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'h9: r9 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'hA: r10 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'hB: r11 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'hC: r12 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'hD: r13 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'hE: r14 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
                4'hF: r15 = {({product_a, 8'b0} + {product_b, 4'b0} + product_c + p0[7:4]), p0[3:0]};
            endcase
        end
        else begin
            case (rd)
                4'h0: r0 = alu_result;
                4'h1: r1 = alu_result;
                4'h2: r2 = alu_result;
                4'h3: r3 = alu_result;
                4'h4: r4 = alu_result;
                4'h5: r5 = alu_result;
                4'h6: r6 = alu_result;
                4'h7: r7 = alu_result;
                4'h8: r8 = alu_result;
                4'h9: r9 = alu_result;
                4'hA: r10 = alu_result;
                4'hB: r11 = alu_result;
                4'hC: r12 = alu_result;
                4'hD: r13 = alu_result;
                4'hE: r14 = alu_result;
                4'hF: r15 = alu_result;
            endcase
        end
    end
    
    // Load: rt = DM[calculated_address]
    else if (flag2) begin
        case (rt)
            4'h0: r0 = sram_do2;
            4'h1: r1 = sram_do2;
            4'h2: r2 = sram_do2;
            4'h3: r3 = sram_do2;
            4'h4: r4 = sram_do2;
            4'h5: r5 = sram_do2;
            4'h6: r6 = sram_do2;
            4'h7: r7 = sram_do2;
            4'h8: r8 = sram_do2;
            4'h9: r9 = sram_do2;
            4'hA: r10 = sram_do2;
            4'hB: r11 = sram_do2;
            4'hC: r12 = sram_do2;
            4'hD: r13 = sram_do2;
            4'hE: r14 = sram_do2;
            4'hF: r15 = sram_do2;
        endcase
    end
end
        

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        alu_result <= 0;
    else begin
        alu_result <= alu_result_next;
    end
end
always @(*) begin
    alu_result_next = 0;
    if(state == INST_EXE) begin// && !opcode[1]) begin
        //if(!opcode[2]) begin
            if(!opcode[0]) begin
                if(func_bit) begin // ADD: rd = rs + rt
                    alu_result_next = reg_rs_data + reg_rt_data;
                end
                else begin // SUB: rd = rs - rt
                    alu_result_next = reg_rs_data - reg_rt_data;
                end
            end
                
            else begin
                alu_result_next = (reg_rs_data < reg_rt_data);
            end
        //end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        flag <= 0;
        flag2 <= 0;
    end
    else begin
        flag <= next_flag;
        flag2 <= flag;
    end
end
always @(*) begin
    next_flag = 0;
    if(state == DATA_ACCESS && cache_hit_data && opcode[0])
        next_flag = 1;
end

//####################################################
//               SRAM Instance
//####################################################
MEM_SRAM sram_inst (
    .A0(sram_addr[0]),  .A1(sram_addr[1]),  .A2(sram_addr[2]),  .A3(sram_addr[3]),
    .A4(sram_addr[4]),  .A5(sram_addr[5]),  .A6(sram_addr[6]),  .A7(sram_addr[7]),
    .DO0(sram_do[0]),   .DO1(sram_do[1]),   .DO2(sram_do[2]),   .DO3(sram_do[3]),
    .DO4(sram_do[4]),   .DO5(sram_do[5]),   .DO6(sram_do[6]),   .DO7(sram_do[7]),
    .DO8(sram_do[8]),   .DO9(sram_do[9]),   .DO10(sram_do[10]), .DO11(sram_do[11]),
    .DO12(sram_do[12]), .DO13(sram_do[13]), .DO14(sram_do[14]), .DO15(sram_do[15]),
    .DI0(sram_di[0]),   .DI1(sram_di[1]),   .DI2(sram_di[2]),   .DI3(sram_di[3]),
    .DI4(sram_di[4]),   .DI5(sram_di[5]),   .DI6(sram_di[6]),   .DI7(sram_di[7]),
    .DI8(sram_di[8]),   .DI9(sram_di[9]),   .DI10(sram_di[10]), .DI11(sram_di[11]),
    .DI12(sram_di[12]), .DI13(sram_di[13]), .DI14(sram_di[14]), .DI15(sram_di[15]),
    .CK(clk),
    .WEB(sram_web),
    .OE(sram_oe),
    .CS(sram_cs)
);


always @(*) begin
    sram_cs = 1;
    sram_oe = 1;
    sram_web = 1;  // read
    sram_addr = 0;
    sram_di = 0;
    case (state)
        INST_FETCH: begin
            sram_addr = cache_offset + 128;
            sram_web = 1; // read
        end 
        INST_MISS_DATA: begin // Write instruction from DRAM to cache
            if(rvalid_m_inf[1]) begin
                sram_addr = cache_fill_counter + 128;
                sram_web = 0; //write
                sram_di = rdata_m_inf[31:16];  // Instruction data
            end
        end
        DATA_ACCESS: begin
            sram_addr = cache_offset;
            if(opcode[0]) begin  //if (opcode == 3'b010) begin // load data to rt
                sram_web = 1; //read
            end
            else begin // store rt into SRAM
                sram_web = 0; // write
                sram_di = reg_rt_data;
            end
        end
        DATA_MISS_DATA: begin // Write data from DRAM to cache
            if (rvalid_m_inf[0]) begin
                sram_addr = cache_fill_counter;
                sram_web = 0; //write
                sram_di = rdata_m_inf[15:0];
            end
        end
    endcase
end

//####################################################
//               AXI4 Control Logic
//####################################################
reg [15:0] store_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        store_data <= 0;
    else if (state == INST_EXE)// (state == DATA_ACCESS && !opcode[0])
        store_data <= reg_rt_data;
end

assign arsize_m_inf = 6'b001001; // 16 bits, 16 bits
assign arburst_m_inf = 4'b0101; // INCR, INCR
assign arlen_m_inf = {2{7'd127}}; // 128 burst, 128 burst
assign awsize_m_inf = 3'b001; // 16 bits
assign awburst_m_inf = 2'b01; // INCR
assign awlen_m_inf = 0; // single burst

assign arid_m_inf[7:4] = (state == INST_MISS_ADDR) ? 1 : 0;
assign arid_m_inf[3:0] = (state == DATA_MISS_ADDR) ? 2 : 0;
assign araddr_m_inf[63:32] = (state == INST_MISS_ADDR) ? {16'h0, cache_base_inst} : 0;
assign araddr_m_inf[31:0]  = (state == DATA_MISS_ADDR) ? {16'h0, cache_base_data} : 0;
assign arvalid_m_inf[1] = (state == INST_MISS_ADDR);
assign arvalid_m_inf[0] = (state == DATA_MISS_ADDR);
assign rready_m_inf[1] = (state == INST_MISS_DATA);
assign rready_m_inf[0] = (state == DATA_MISS_DATA);

reg [15:0] awaddr;
assign awid_m_inf = (state == STORE_ADDR) ? 3 : 0;
assign awaddr_m_inf = (state == STORE_ADDR) ? awaddr : 0;
assign awvalid_m_inf = (state == STORE_ADDR);

assign wdata_m_inf = (state == STORE_DATA) ? store_data : 0;
assign wlast_m_inf = (state == STORE_DATA);
assign wvalid_m_inf = (state == STORE_DATA);
assign bready_m_inf = (state == STORE_RESP);



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        awaddr <= 0;
    end
    else if (state == CAL_ADDR) begin
        awaddr <= {16'h0, data_addr};
    end
end

endmodule
