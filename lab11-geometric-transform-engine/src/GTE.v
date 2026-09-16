//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   ICLAB 2025 Fall 
// Lab11 Exercise : Geometric Transform Engine (GTE)
//      File Name : GTE.v
//    Module Name : GTE
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module GTE(
    // input signals
    clk,
    rst_n,
	
    in_valid_data,
	data,
	
    in_valid_cmd,
    cmd,    
	
    // output signals
    busy
);

input              clk;
input              rst_n;

input              in_valid_data;
input       [7:0]  data;

input              in_valid_cmd;
input      [17:0]  cmd;

output reg         busy;

//==================================================================
// parameter & integer
//==================================================================
parameter IDLE = 3'd0;
parameter LOAD_DATA = 3'd1;
parameter IDLE_CMD = 3'd2;
parameter READ = 3'd3;
parameter EXE = 3'd4;
parameter WRITE = 3'd5;


parameter EXE2 = 3'd6;

//==================================================================
// reg & wire
//==================================================================
reg [2:0] state, next_state, last_state;


reg [14:0] data_cnt;  // 32768 = 128 * 16 * 16
reg [7:0] data_r;
reg [6:0] ms, md;
reg [1:0] opcode, funct;
reg [7:0] read_cnt;
reg [7:0] write_cnt;
reg [3:0] row, col;

reg [3:0] src_row, src_col;
reg [7:0] temp_image [0:255];

reg [7:0] pixel_read_8bit;
reg [15:0] pixel_read_16bit;
reg [31:0] pixel_read_32bit;

reg [7:0] pixel_to_write;


reg        mem0_web_r, mem1_web_r, mem2_web_r, mem3_web_r;
reg [11:0] mem0_addr_r, mem1_addr_r, mem2_addr_r, mem3_addr_r;
reg  [7:0] mem0_din_r, mem1_din_r, mem2_din_r, mem3_din_r;

reg        mem4_web_r, mem5_web_r;
reg [10:0] mem4_addr_r, mem5_addr_r;
reg [15:0] mem4_din_r, mem5_din_r;

reg        mem6_web_r, mem7_web_r;
reg  [9:0] mem6_addr_r, mem7_addr_r;
reg [31:0] mem6_din_r, mem7_din_r;

// -----------------------------------------------------
// MEM
// -----------------------------------------------------

// MEM_0, MEM_1, MEM_2, MEM_3: 8-bit width, 4096 depth
wire        mem0_web, mem1_web, mem2_web, mem3_web;
wire [11:0] mem0_addr, mem1_addr, mem2_addr, mem3_addr;
wire  [7:0] mem0_din, mem1_din, mem2_din, mem3_din;
wire  [7:0] mem0_dout, mem1_dout, mem2_dout, mem3_dout;

// MEM_4, MEM_5: 16-bit width, 2048 depth
wire        mem4_web, mem5_web;
wire [10:0] mem4_addr, mem5_addr;
wire [15:0] mem4_din, mem5_din;
wire [15:0] mem4_dout, mem5_dout;

// MEM_6, MEM_7: 32-bit width, 1024 depth
wire        mem6_web, mem7_web;
wire  [9:0] mem6_addr, mem7_addr;
wire [31:0] mem6_din, mem7_din;
wire [31:0] mem6_dout, mem7_dout;

//==================================================================
// design
//==================================================================
//---------------------------------------------
// State
//---------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        last_state <= IDLE;
    end
    else begin
        state <= next_state;
        last_state <= state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (in_valid_data)
                next_state = LOAD_DATA;
        end
        LOAD_DATA: begin
            if (!in_valid_data && data_cnt == 32767)
                next_state = IDLE_CMD;
        end
        IDLE_CMD: begin
            if(in_valid_cmd)
                next_state = READ;
        end
        READ: begin
            case (ms[6:4])
                3'd0, 3'd1, 3'd2, 3'd3: begin
                    if (read_cnt == 255)
                        next_state = EXE;
                end
                3'd4, 3'd5: begin
                    if (read_cnt == 254)
                        next_state = EXE;
                end
                3'd6, 3'd7: begin
                    if (read_cnt == 252)
                        next_state = EXE;
                end
            endcase
        end
        EXE: begin
            next_state = EXE2;
        end
        EXE2: next_state = WRITE;
        WRITE: begin
            if (write_cnt == 255)
                next_state = IDLE_CMD;
            else
                next_state = WRITE;
        end
        default: next_state = IDLE;
    endcase
end

//---------------------------------------------
// Input
//---------------------------------------------
reg [7:0] pixel_buf, pixel_buf1, pixel_buf2, pixel_buf3;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_r <= 15'd0;
    end
    else if (in_valid_data) begin
        data_r <= data;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_buf <= 8'd0;
    end
    else if (in_valid_data) begin
        if (data_cnt[0] == 0)  // Even pixel
            pixel_buf <= data_r;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_buf1 <= 8'd0;
        pixel_buf2 <= 8'd0;
        pixel_buf3 <= 8'd0;
    end
    else if (in_valid_data) begin
        case (data_cnt[1:0])
            2'b00: pixel_buf1 <= data_r;
            2'b01: pixel_buf2 <= data_r;
            2'b10: pixel_buf3 <= data_r;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_cnt <= 15'd0;
    end
    else if (state == LOAD_DATA) begin
        data_cnt <= data_cnt + 1;
    end
    else begin
        data_cnt <= 15'd0;
    end
end

//==================================================================
// Command 
//==================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        opcode <= 2'd0;
        funct <= 2'd0;
        ms <= 7'd0;
        md <= 7'd0;
    end
    else if (in_valid_cmd) begin
        opcode <= cmd[17:16];
        funct <= cmd[15:14];
        ms <= cmd[13:7];
        md <= cmd[6:0];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_cnt <= 8'd0;
    end
    else if (state == READ) begin
        case (ms[6:4])
            3'd0, 3'd1, 3'd2, 3'd3: begin
                read_cnt <= read_cnt + 1;
            end
            3'd4, 3'd5: begin
                read_cnt <= read_cnt + 2;
            end
            3'd6, 3'd7: begin
                read_cnt <= read_cnt + 4;
            end
        endcase
    end
    else if (state == IDLE_CMD) begin
        read_cnt <= 8'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_cnt <= 8'd0;
    end
    else if (state == WRITE) begin
        write_cnt <= write_cnt + 1;
    end
    else if (state == EXE) begin
        write_cnt <= 8'd0;
    end
end

wire [3:0] read_row = read_cnt[7:4];
wire [3:0] read_col = read_cnt[3:0];


//==================================================================
// Coordinate Transformation Logic
//==================================================================

always @(*) begin
    row = write_cnt[7:4];
    col = write_cnt[3:0];

    src_row = row;
    src_col = col;
    
    case (opcode)
        2'b00: begin  // Mirror
            case (funct)
                2'b00: begin  // MX
                    src_row = 15 - row;
                    src_col = col;
                end
                2'b01: begin  // MY
                    src_row = row;
                    src_col = 15 - col;
                end
                2'b10: begin  // TRP
                    src_row = col;
                    src_col = row;
                end
                2'b11: begin  // STRP
                    src_row = 15 - col;
                    src_col = 15 - row;
                end
            endcase
        end
        
        2'b01: begin  // Rotation
            case (funct)
                2'b00: begin  // R90
                    src_row = 15 - col;
                    src_col = row;
                end
                2'b01: begin  // R180
                    src_row = 15 - row;
                    src_col = 15 - col;
                end
                2'b10: begin  // R270
                    src_row = col;
                    src_col = 15 - row;
                end
            endcase
        end
        
        2'b10: begin  // Shift
            case (funct)
                2'b00: begin  // RS
                    if (col < 5) begin
                        src_row = row;
                        src_col = 4 - col;
                    end
                    else begin
                        src_row = row;
                        src_col = col - 5;
                    end
                end
                2'b01: begin  // LS
                    if (col > 10) begin
                        src_row = row;
                        src_col = 26 - col;  // 15-(col-11) = 26-col
                    end
                    else begin
                        src_row = row;
                        src_col = col + 5;
                    end
                end
                2'b10: begin  // US
                    if (row > 10) begin
                        src_row = 26 - row;
                        src_col = col;
                    end
                    else begin
                        src_row = row + 5;
                        src_col = col;
                    end
                end
                2'b11: begin  // DS
                    if (row < 5) begin
                        src_row = 4 - row;
                        src_col = col;
                    end
                    else begin
                        src_row = row - 5;
                        src_col = col;
                    end
                end
            endcase
        end
        
        2'b11: begin  // Reorder
            case (funct)
                2'b00: begin  // ZZ4
                    src_row = zigzag4_row(row, col);
                    src_col = zigzag4_col(row, col);
                end
                2'b01: begin  // ZZ8
                    src_row = zigzag8_row(row, col);
                    src_col = zigzag8_col(row, col);
                end
                2'b10: begin  // MO4
                    src_row = morton4_row(row, col);
                    src_col = morton4_col(row, col);
                end
                2'b11: begin  // MO8
                    src_row = morton8_row(row, col);
                    src_col = morton8_col(row, col);
                end
            endcase
        end
    endcase
end

//==================================================================
// SRAM Read
//==================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_read_8bit <= 8'd0;
        pixel_read_16bit <= 16'd0;
        pixel_read_32bit <= 32'd0;
    end
    else if (last_state == READ) begin
        case (ms[6:4])
            3'd0: pixel_read_8bit <= mem0_dout;
            3'd1: pixel_read_8bit <= mem1_dout;
            3'd2: pixel_read_8bit <= mem2_dout;
            3'd3: pixel_read_8bit <= mem3_dout;
            3'd4: pixel_read_16bit <= mem4_dout;
            3'd5: pixel_read_16bit <= mem5_dout;
            3'd6: pixel_read_32bit <= mem6_dout;
            3'd7: pixel_read_32bit <= mem7_dout;
        endcase
    end
end

reg [7:0] read_cnt_r, read_cnt_r2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        read_cnt_r <= 0;
        read_cnt_r2 <= 0;
    end
    else begin
        read_cnt_r <= read_cnt;
        read_cnt_r2 <= read_cnt_r;
    end
end

reg [7:0] temp [0:255];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
    end
    else begin
        for (integer i = 0;i < 256;i = i + 1) begin
            temp_image[i] <= temp[i];
        end
    end
end
always @(*) begin
    for (integer i = 0;i < 256;i = i + 1) begin
        temp[i] = temp_image[i];
    end

    if (last_state == READ || last_state == EXE) begin
        case (ms[6:4])
            3'd0, 3'd1, 3'd2, 3'd3: begin
                temp[read_cnt_r2] = pixel_read_8bit;
            end
            3'd4, 3'd5: begin
                temp[{read_cnt_r2[7:1], 1'b0}] = pixel_read_16bit[15:8];
                temp[{read_cnt_r2[7:1], 1'b1}] = pixel_read_16bit[7:0];
            end
            3'd6, 3'd7: begin
                temp[{read_cnt_r2[7:2], 2'd0}] = pixel_read_32bit[31:24];
                temp[{read_cnt_r2[7:2], 2'd1}] = pixel_read_32bit[23:16];
                temp[{read_cnt_r2[7:2], 2'd2}] = pixel_read_32bit[15:8];
                temp[{read_cnt_r2[7:2], 2'd3}] = pixel_read_32bit[7:0];
            end
        endcase
    end
    else if (state == IDLE) begin
        for (integer i = 0;i < 256;i = i + 1) begin
            temp[i] = 0;
        end
    end
end


//==================================================================
// SRAM Write
//==================================================================
reg [7:0] write_buf;
reg [7:0] write_buf1, write_buf2, write_buf3;

always @(*) begin
    pixel_to_write = temp_image[{src_row, src_col}];
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_buf <= 8'd0;
    end
    else if (state == WRITE) begin
        if (col[0] == 0)  // Even column
            write_buf <= pixel_to_write;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        write_buf1 <= 8'd0;
        write_buf2 <= 8'd0;
        write_buf3 <= 8'd0;
    end
    else if (state == WRITE) begin
        case (col[1:0])
            2'b00: write_buf1 <= pixel_to_write;
            2'b01: write_buf2 <= pixel_to_write;
            2'b10: write_buf3 <= pixel_to_write;
        endcase
    end
end

//==================================================================
// Busy Signal
//==================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy <= 1'b1;
    end
    else if (state == WRITE && write_cnt == 255) begin
        busy <= 1'b0;
    end
    else begin
        busy <= 1'b1;
    end
end

//---------------------------------------------
// SRAM
//---------------------------------------------
always @(*) begin
    mem0_web_r = 1'b1;
    mem1_web_r = 1'b1;
    mem2_web_r = 1'b1;
    mem3_web_r = 1'b1;
    mem4_web_r = 1'b1;
    mem5_web_r = 1'b1;
    mem6_web_r = 1'b1;
    mem7_web_r = 1'b1;
    mem0_addr_r = 12'd0;
    mem1_addr_r = 12'd0;
    mem2_addr_r = 12'd0;
    mem3_addr_r = 12'd0;
    mem4_addr_r = 11'd0;
    mem5_addr_r = 11'd0;
    mem6_addr_r = 10'd0;
    mem7_addr_r = 10'd0;
    mem0_din_r = 8'd0;
    mem1_din_r = 8'd0;
    mem2_din_r = 8'd0;
    mem3_din_r = 8'd0;
    mem4_din_r = 16'd0;
    mem5_din_r = 16'd0;
    mem6_din_r = 32'd0;
    mem7_din_r = 32'd0;
    
    // ===== LOAD =====
    if (state == LOAD_DATA) begin
        // Image 0~127 : data_cnt[14:8]
        // Pixel 0~256 : data_cnt[7:0]
        
        case (data_cnt[14:12]) // image / 16
            // MEM0: Images 0-15
            3'd0: begin
                mem0_web_r = 1'b0;
                mem0_addr_r = data_cnt[11:0];
                mem0_din_r = data_r;
            end
            
            // MEM1: Images 16-31
            3'd1: begin
                mem1_web_r = 1'b0;
                mem1_addr_r = data_cnt[11:0];
                mem1_din_r = data_r;
            end
            
            // MEM2: Images 32-47
            3'd2: begin
                mem2_web_r = 1'b0;
                mem2_addr_r = data_cnt[11:0];
                mem2_din_r = data_r;
            end
            
            // MEM3: Images 48-63
            3'd3: begin
                mem3_web_r = 1'b0;
                mem3_addr_r = data_cnt[11:0];
                mem3_din_r = data_r;
            end
            
            // MEM4: Images 64-79 (Width: 8 * 2)
            3'd4: begin
                mem4_addr_r = data_cnt[11:1];
                if (data_cnt[0] == 1) begin  // Odd
                    mem4_web_r = 1'b0;
                    mem4_din_r = {pixel_buf, data_r};
                end
            end
            
            // MEM5: Images 80-95 (Width: 8 * 2)
            3'd5: begin
                mem5_addr_r = data_cnt[11:1];
                if (data_cnt[0] == 1) begin  // Odd
                    mem5_web_r = 1'b0;
                    mem5_din_r = {pixel_buf, data_r};
                end
            end
            
            // MEM6: Images 96-111 (Width: 8 * 4)
            3'd6: begin
                mem6_addr_r = data_cnt[11:2];
                if (data_cnt[1:0] == 2'b11) begin  // 4th pixel
                    mem6_web_r = 1'b0;
                    mem6_din_r = {pixel_buf1, pixel_buf2, pixel_buf3, data_r};
                end
            end
            
            // MEM7: Images 112-127 (Width: 8 * 4)
            3'd7: begin
                mem7_addr_r = data_cnt[11:2];
                if (data_cnt[1:0] == 2'b11) begin  // 4th pixel
                    mem7_web_r = 1'b0;
                    mem7_din_r = {pixel_buf1, pixel_buf2, pixel_buf3, data_r};
                end
            end
        endcase
    end


    // ===== READ =====
    else if (state == READ) begin
        case (ms[6:4])
            3'd0: begin
                mem0_addr_r = {ms[3:0], read_cnt};
            end
            3'd1: begin
                mem1_addr_r = {ms[3:0], read_cnt};
            end
            3'd2: begin
                mem2_addr_r = {ms[3:0], read_cnt};
            end
            3'd3: begin
                mem3_addr_r = {ms[3:0], read_cnt};
            end
            3'd4: begin
                mem4_addr_r = {ms[3:0], read_cnt[7:1]};
            end
            3'd5: begin
                mem5_addr_r = {ms[3:0], read_cnt[7:1]};
            end
            3'd6: begin
                mem6_addr_r = {ms[3:0], read_cnt[7:2]};
            end
            3'd7: begin
                mem7_addr_r = {ms[3:0], read_cnt[7:2]};
            end
        endcase
    end
    
    // ===== WRITE =====
    else if (state == WRITE) begin
        case (md[6:4])
            3'd0: begin
                mem0_web_r = 0;
                mem0_addr_r = {md[3:0], row, col};
                mem0_din_r = pixel_to_write;
            end
            
            3'd1: begin
                mem1_web_r = 0;
                mem1_addr_r = {md[3:0], row, col};
                mem1_din_r = pixel_to_write;
            end
            
            3'd2: begin
                mem2_web_r = 0;
                mem2_addr_r = {md[3:0], row, col};
                mem2_din_r = pixel_to_write;
            end
            
            3'd3: begin
                mem3_web_r = 0;
                mem3_addr_r = {md[3:0], row, col};
                mem3_din_r = pixel_to_write;
            end
            
            3'd4: begin
                mem4_addr_r = {md[3:0], row, col[3:1]};
                if (col[0] == 1) begin
                    mem4_web_r = 0;
                    mem4_din_r = {write_buf, pixel_to_write};
                end
            end
            
            3'd5: begin
                mem5_addr_r = {md[3:0], row, col[3:1]};
                if (col[0] == 1) begin
                    mem5_web_r = 0;
                    mem5_din_r = {write_buf, pixel_to_write};
                end
            end
            
            3'd6: begin
                mem6_addr_r = {md[3:0], row, col[3:2]};
                if (col[1:0] == 2'b11) begin
                    mem6_web_r = 0;
                    mem6_din_r = {write_buf1, write_buf2, write_buf3, pixel_to_write};
                end
            end
            
            3'd7: begin
                mem7_addr_r = {md[3:0], row, col[3:2]};
                if (col[1:0] == 2'b11) begin
                    mem7_web_r = 0;
                    mem7_din_r = {write_buf1, write_buf2, write_buf3, pixel_to_write};
                end
            end
        endcase
    end
end

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/* 
  There are eight SRAMs in your GTE. You should not change the name of those SRAMs.
  TA will check the value in each SRAMs when your GTE is not busy.
  If you change the name of SRAMs below, you must get the fail in this lab.
  
  You should finish SRAM-related signals assignments for each SRAM.
*/
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// SRAM-related signals assignments
assign mem0_addr = mem0_addr_r;
assign mem0_web  = mem0_web_r;
assign mem0_din  = mem0_din_r;

assign mem1_addr = mem1_addr_r;
assign mem1_web  = mem1_web_r;
assign mem1_din  = mem1_din_r;

assign mem2_addr = mem2_addr_r;
assign mem2_web  = mem2_web_r;
assign mem2_din  = mem2_din_r;

assign mem3_addr = mem3_addr_r;
assign mem3_web  = mem3_web_r;
assign mem3_din  = mem3_din_r;

assign mem4_addr = mem4_addr_r;
assign mem4_web  = mem4_web_r;
assign mem4_din  = mem4_din_r;

assign mem5_addr = mem5_addr_r;
assign mem5_web  = mem5_web_r;
assign mem5_din  = mem5_din_r;

assign mem6_addr = mem6_addr_r;
assign mem6_web  = mem6_web_r;
assign mem6_din  = mem6_din_r;

assign mem7_addr = mem7_addr_r;
assign mem7_web  = mem7_web_r;
assign mem7_din  = mem7_din_r;

// MEM_0, MEM_1, MEM_2, MEM_3, MEM_4, MEM_5, MEM_6, MEM_7 instantiation
sram_4096x8 MEM0(
    .A0(mem0_addr[0]), .A1(mem0_addr[1]), .A2(mem0_addr[2]), .A3(mem0_addr[3]), .A4(mem0_addr[4]), .A5(mem0_addr[5]), .A6(mem0_addr[6]), .A7(mem0_addr[7]), 
    .A8(mem0_addr[8]), .A9(mem0_addr[9]), .A10(mem0_addr[10]), .A11(mem0_addr[11]),
    .DO0(mem0_dout[0]), .DO1(mem0_dout[1]), .DO2(mem0_dout[2]), .DO3(mem0_dout[3]), .DO4(mem0_dout[4]), .DO5(mem0_dout[5]), .DO6(mem0_dout[6]), .DO7(mem0_dout[7]),
    .DI0(mem0_din[0]), .DI1(mem0_din[1]), .DI2(mem0_din[2]), .DI3(mem0_din[3]), .DI4(mem0_din[4]), .DI5(mem0_din[5]), .DI6(mem0_din[6]), .DI7(mem0_din[7]),
    .CK(clk), .WEB(mem0_web), .OE(1'b1), .CS(1'b1)
);

sram_4096x8 MEM1(
    .A0(mem1_addr[0]), .A1(mem1_addr[1]), .A2(mem1_addr[2]), .A3(mem1_addr[3]), .A4(mem1_addr[4]), .A5(mem1_addr[5]), .A6(mem1_addr[6]), .A7(mem1_addr[7]), 
    .A8(mem1_addr[8]), .A9(mem1_addr[9]), .A10(mem1_addr[10]), .A11(mem1_addr[11]),
    .DO0(mem1_dout[0]), .DO1(mem1_dout[1]), .DO2(mem1_dout[2]), .DO3(mem1_dout[3]), .DO4(mem1_dout[4]), .DO5(mem1_dout[5]), .DO6(mem1_dout[6]), .DO7(mem1_dout[7]),
    .DI0(mem1_din[0]), .DI1(mem1_din[1]), .DI2(mem1_din[2]), .DI3(mem1_din[3]), .DI4(mem1_din[4]), .DI5(mem1_din[5]), .DI6(mem1_din[6]), .DI7(mem1_din[7]),
    .CK(clk), .WEB(mem1_web), .OE(1'b1), .CS(1'b1)
);

sram_4096x8 MEM2 (
    .A0(mem2_addr[0]), .A1(mem2_addr[1]), .A2(mem2_addr[2]), .A3(mem2_addr[3]), .A4(mem2_addr[4]), .A5(mem2_addr[5]), .A6(mem2_addr[6]), .A7(mem2_addr[7]),
    .A8(mem2_addr[8]), .A9(mem2_addr[9]), .A10(mem2_addr[10]), .A11(mem2_addr[11]),
    .DO0(mem2_dout[0]), .DO1(mem2_dout[1]), .DO2(mem2_dout[2]), .DO3(mem2_dout[3]), .DO4(mem2_dout[4]), .DO5(mem2_dout[5]), .DO6(mem2_dout[6]), .DO7(mem2_dout[7]),
    .DI0(mem2_din[0]), .DI1(mem2_din[1]), .DI2(mem2_din[2]), .DI3(mem2_din[3]), .DI4(mem2_din[4]), .DI5(mem2_din[5]), .DI6(mem2_din[6]), .DI7(mem2_din[7]),
    .CK(clk), .WEB(mem2_web), .OE(1'b1), .CS(1'b1)
);

sram_4096x8 MEM3(
    .A0(mem3_addr[0]), .A1(mem3_addr[1]), .A2(mem3_addr[2]), .A3(mem3_addr[3]), .A4(mem3_addr[4]), .A5(mem3_addr[5]), .A6(mem3_addr[6]), .A7(mem3_addr[7]), 
    .A8(mem3_addr[8]), .A9(mem3_addr[9]), .A10(mem3_addr[10]), .A11(mem3_addr[11]),
    .DO0(mem3_dout[0]), .DO1(mem3_dout[1]), .DO2(mem3_dout[2]), .DO3(mem3_dout[3]), .DO4(mem3_dout[4]), .DO5(mem3_dout[5]), .DO6(mem3_dout[6]), .DO7(mem3_dout[7]),
    .DI0(mem3_din[0]), .DI1(mem3_din[1]), .DI2(mem3_din[2]), .DI3(mem3_din[3]), .DI4(mem3_din[4]), .DI5(mem3_din[5]), .DI6(mem3_din[6]), .DI7(mem3_din[7]),
    .CK(clk), .WEB(mem3_web), .OE(1'b1), .CS(1'b1)
);

sram_2048x16 MEM4(
	.A0(mem4_addr[0]), .A1(mem4_addr[1]), .A2(mem4_addr[2]), .A3(mem4_addr[3]), .A4(mem4_addr[4]), .A5(mem4_addr[5]), .A6(mem4_addr[6]), .A7(mem4_addr[7]), 
	.A8(mem4_addr[8]), .A9(mem4_addr[9]), .A10(mem4_addr[10]),
	.DO0(mem4_dout[0]), .DO1(mem4_dout[1]), .DO2(mem4_dout[2]), .DO3(mem4_dout[3]), .DO4(mem4_dout[4]), .DO5(mem4_dout[5]), .DO6(mem4_dout[6]), .DO7(mem4_dout[7]), 
	.DO8(mem4_dout[8]), .DO9(mem4_dout[9]), .DO10(mem4_dout[10]), .DO11(mem4_dout[11]), .DO12(mem4_dout[12]), .DO13(mem4_dout[13]), .DO14(mem4_dout[14]), .DO15(mem4_dout[15]),
	.DI0(mem4_din[0]), .DI1(mem4_din[1]), .DI2(mem4_din[2]), .DI3(mem4_din[3]), .DI4(mem4_din[4]), .DI5(mem4_din[5]), .DI6(mem4_din[6]), .DI7(mem4_din[7]), 
	.DI8(mem4_din[8]), .DI9(mem4_din[9]), .DI10(mem4_din[10]), .DI11(mem4_din[11]), .DI12(mem4_din[12]), .DI13(mem4_din[13]), .DI14(mem4_din[14]), .DI15(mem4_din[15]),
	.CK(clk), .WEB(mem4_web), .OE(1'b1), .CS(1'b1)
);

sram_2048x16 MEM5(
	.A0(mem5_addr[0]), .A1(mem5_addr[1]), .A2(mem5_addr[2]), .A3(mem5_addr[3]), .A4(mem5_addr[4]), .A5(mem5_addr[5]), .A6(mem5_addr[6]), .A7(mem5_addr[7]), 
	.A8(mem5_addr[8]), .A9(mem5_addr[9]), .A10(mem5_addr[10]),
	.DO0(mem5_dout[0]), .DO1(mem5_dout[1]), .DO2(mem5_dout[2]), .DO3(mem5_dout[3]), .DO4(mem5_dout[4]), .DO5(mem5_dout[5]), .DO6(mem5_dout[6]), .DO7(mem5_dout[7]), 
	.DO8(mem5_dout[8]), .DO9(mem5_dout[9]), .DO10(mem5_dout[10]), .DO11(mem5_dout[11]), .DO12(mem5_dout[12]), .DO13(mem5_dout[13]), .DO14(mem5_dout[14]), .DO15(mem5_dout[15]),
	.DI0(mem5_din[0]), .DI1(mem5_din[1]), .DI2(mem5_din[2]), .DI3(mem5_din[3]), .DI4(mem5_din[4]), .DI5(mem5_din[5]), .DI6(mem5_din[6]), .DI7(mem5_din[7]), 
	.DI8(mem5_din[8]), .DI9(mem5_din[9]), .DI10(mem5_din[10]), .DI11(mem5_din[11]), .DI12(mem5_din[12]), .DI13(mem5_din[13]), .DI14(mem5_din[14]), .DI15(mem5_din[15]),
	.CK(clk), .WEB(mem5_web), .OE(1'b1), .CS(1'b1)
);

sram_1024x32 MEM6(
	.A0(mem6_addr[0]), .A1(mem6_addr[1]), .A2(mem6_addr[2]), .A3(mem6_addr[3]), .A4(mem6_addr[4]), .A5(mem6_addr[5]), .A6(mem6_addr[6]), .A7(mem6_addr[7]), 
	.A8(mem6_addr[8]), .A9(mem6_addr[9]),
	.DO0(mem6_dout[0]), .DO1(mem6_dout[1]), .DO2(mem6_dout[2]), .DO3(mem6_dout[3]), .DO4(mem6_dout[4]), .DO5(mem6_dout[5]), .DO6(mem6_dout[6]), .DO7(mem6_dout[7]), 
	.DO8(mem6_dout[8]), .DO9(mem6_dout[9]), .DO10(mem6_dout[10]), .DO11(mem6_dout[11]), .DO12(mem6_dout[12]), .DO13(mem6_dout[13]), .DO14(mem6_dout[14]), .DO15(mem6_dout[15]), 
	.DO16(mem6_dout[16]), .DO17(mem6_dout[17]), .DO18(mem6_dout[18]), .DO19(mem6_dout[19]), .DO20(mem6_dout[20]), .DO21(mem6_dout[21]), .DO22(mem6_dout[22]), .DO23(mem6_dout[23]), 
	.DO24(mem6_dout[24]), .DO25(mem6_dout[25]), .DO26(mem6_dout[26]), .DO27(mem6_dout[27]), .DO28(mem6_dout[28]), .DO29(mem6_dout[29]), .DO30(mem6_dout[30]), .DO31(mem6_dout[31]),
	.DI0(mem6_din[0]), .DI1(mem6_din[1]), .DI2(mem6_din[2]), .DI3(mem6_din[3]), .DI4(mem6_din[4]), .DI5(mem6_din[5]), .DI6(mem6_din[6]), .DI7(mem6_din[7]), 
	.DI8(mem6_din[8]), .DI9(mem6_din[9]), .DI10(mem6_din[10]), .DI11(mem6_din[11]), .DI12(mem6_din[12]), .DI13(mem6_din[13]), .DI14(mem6_din[14]), .DI15(mem6_din[15]), 
	.DI16(mem6_din[16]), .DI17(mem6_din[17]), .DI18(mem6_din[18]), .DI19(mem6_din[19]), .DI20(mem6_din[20]), .DI21(mem6_din[21]), .DI22(mem6_din[22]), .DI23(mem6_din[23]), 
	.DI24(mem6_din[24]), .DI25(mem6_din[25]), .DI26(mem6_din[26]), .DI27(mem6_din[27]), .DI28(mem6_din[28]), .DI29(mem6_din[29]), .DI30(mem6_din[30]), .DI31(mem6_din[31]),
	.CK(clk), .WEB(mem6_web), .OE(1'b1), .CS(1'b1)
);

sram_1024x32 MEM7(
	.A0(mem7_addr[0]), .A1(mem7_addr[1]), .A2(mem7_addr[2]), .A3(mem7_addr[3]), .A4(mem7_addr[4]), .A5(mem7_addr[5]), .A6(mem7_addr[6]), .A7(mem7_addr[7]), 
	.A8(mem7_addr[8]), .A9(mem7_addr[9]),
	.DO0(mem7_dout[0]), .DO1(mem7_dout[1]), .DO2(mem7_dout[2]), .DO3(mem7_dout[3]), .DO4(mem7_dout[4]), .DO5(mem7_dout[5]), .DO6(mem7_dout[6]), .DO7(mem7_dout[7]), 
	.DO8(mem7_dout[8]), .DO9(mem7_dout[9]), .DO10(mem7_dout[10]), .DO11(mem7_dout[11]), .DO12(mem7_dout[12]), .DO13(mem7_dout[13]), .DO14(mem7_dout[14]), .DO15(mem7_dout[15]), 
	.DO16(mem7_dout[16]), .DO17(mem7_dout[17]), .DO18(mem7_dout[18]), .DO19(mem7_dout[19]), .DO20(mem7_dout[20]), .DO21(mem7_dout[21]), .DO22(mem7_dout[22]), .DO23(mem7_dout[23]), 
	.DO24(mem7_dout[24]), .DO25(mem7_dout[25]), .DO26(mem7_dout[26]), .DO27(mem7_dout[27]), .DO28(mem7_dout[28]), .DO29(mem7_dout[29]), .DO30(mem7_dout[30]), .DO31(mem7_dout[31]),
	.DI0(mem7_din[0]), .DI1(mem7_din[1]), .DI2(mem7_din[2]), .DI3(mem7_din[3]), .DI4(mem7_din[4]), .DI5(mem7_din[5]), .DI6(mem7_din[6]), .DI7(mem7_din[7]), 
	.DI8(mem7_din[8]), .DI9(mem7_din[9]), .DI10(mem7_din[10]), .DI11(mem7_din[11]), .DI12(mem7_din[12]), .DI13(mem7_din[13]), .DI14(mem7_din[14]), .DI15(mem7_din[15]), 
	.DI16(mem7_din[16]), .DI17(mem7_din[17]), .DI18(mem7_din[18]), .DI19(mem7_din[19]), .DI20(mem7_din[20]), .DI21(mem7_din[21]), .DI22(mem7_din[22]), .DI23(mem7_din[23]), 
	.DI24(mem7_din[24]), .DI25(mem7_din[25]), .DI26(mem7_din[26]), .DI27(mem7_din[27]), .DI28(mem7_din[28]), .DI29(mem7_din[29]), .DI30(mem7_din[30]), .DI31(mem7_din[31]),
	.CK(clk), .WEB(mem7_web), .OE(1'b1), .CS(1'b1)
);





//==================================================================
// 4x4 Zig-zag
//==================================================================
function [3:0] zigzag4_row;
    input [3:0] dst_row, dst_col;
    reg [1:0] block_row, block_col;
    reg [1:0] in_block_row, in_block_col;
    reg [3:0] zz_idx;
    begin
        block_row = dst_row[3:2];  // Which 4x4 block vertically (0-3)
        block_col = dst_col[3:2];  // Which 4x4 block horizontally (0-3)
        zz_idx = {dst_row[1:0], dst_col[1:0]};  // Position within 4x4 block
        
        // Inverse zig-zag mapping: output position -> source position
        case (zz_idx)
            4'd0:  begin in_block_row = 2'd0; in_block_col = 2'd0; end  // 0 -> (0,0)
            4'd1:  begin in_block_row = 2'd0; in_block_col = 2'd1; end  // 1 -> (0,1)
            4'd2:  begin in_block_row = 2'd1; in_block_col = 2'd0; end  // 2 -> (1,0)
            4'd3:  begin in_block_row = 2'd2; in_block_col = 2'd0; end  // 3 -> (2,0)
            4'd4:  begin in_block_row = 2'd1; in_block_col = 2'd1; end  // 4 -> (1,1)
            4'd5:  begin in_block_row = 2'd0; in_block_col = 2'd2; end  // 5 -> (0,2)
            4'd6:  begin in_block_row = 2'd0; in_block_col = 2'd3; end  // 6 -> (0,3)
            4'd7:  begin in_block_row = 2'd1; in_block_col = 2'd2; end  // 7 -> (1,2)
            4'd8:  begin in_block_row = 2'd2; in_block_col = 2'd1; end  // 8 -> (2,1)
            4'd9:  begin in_block_row = 2'd3; in_block_col = 2'd0; end  // 9 -> (3,0)
            4'd10: begin in_block_row = 2'd3; in_block_col = 2'd1; end  // 10 -> (3,1)
            4'd11: begin in_block_row = 2'd2; in_block_col = 2'd2; end  // 11 -> (2,2)
            4'd12: begin in_block_row = 2'd1; in_block_col = 2'd3; end  // 12 -> (1,3)
            4'd13: begin in_block_row = 2'd2; in_block_col = 2'd3; end  // 13 -> (2,3)
            4'd14: begin in_block_row = 2'd3; in_block_col = 2'd2; end  // 14 -> (3,2)
            4'd15: begin in_block_row = 2'd3; in_block_col = 2'd3; end  // 15 -> (3,3)
        endcase
        
        zigzag4_row = {block_row, in_block_row};
    end
endfunction

function [3:0] zigzag4_col;
    input [3:0] dst_row, dst_col;
    reg [1:0] block_row, block_col;
    reg [1:0] in_block_row, in_block_col;
    reg [3:0] zz_idx;
    begin
        block_row = dst_row[3:2];
        block_col = dst_col[3:2];
        zz_idx = {dst_row[1:0], dst_col[1:0]};
        
        case (zz_idx)
            4'd0:  begin in_block_row = 2'd0; in_block_col = 2'd0; end
            4'd1:  begin in_block_row = 2'd0; in_block_col = 2'd1; end
            4'd2:  begin in_block_row = 2'd1; in_block_col = 2'd0; end
            4'd3:  begin in_block_row = 2'd2; in_block_col = 2'd0; end
            4'd4:  begin in_block_row = 2'd1; in_block_col = 2'd1; end
            4'd5:  begin in_block_row = 2'd0; in_block_col = 2'd2; end
            4'd6:  begin in_block_row = 2'd0; in_block_col = 2'd3; end
            4'd7:  begin in_block_row = 2'd1; in_block_col = 2'd2; end
            4'd8:  begin in_block_row = 2'd2; in_block_col = 2'd1; end
            4'd9:  begin in_block_row = 2'd3; in_block_col = 2'd0; end
            4'd10: begin in_block_row = 2'd3; in_block_col = 2'd1; end
            4'd11: begin in_block_row = 2'd2; in_block_col = 2'd2; end
            4'd12: begin in_block_row = 2'd1; in_block_col = 2'd3; end
            4'd13: begin in_block_row = 2'd2; in_block_col = 2'd3; end
            4'd14: begin in_block_row = 2'd3; in_block_col = 2'd2; end
            4'd15: begin in_block_row = 2'd3; in_block_col = 2'd3; end
        endcase
        
        zigzag4_col = {block_col, in_block_col};
    end
endfunction

//==================================================================
// 8x8 Zig-zag
//==================================================================
function [3:0] zigzag8_row;
    input [3:0] dst_row, dst_col;
    reg [0:0] block_row, block_col;
    reg [2:0] in_block_row, in_block_col;
    reg [5:0] zz_idx;
    begin
        block_row = dst_row[3];  // Which 8x8 block vertically (0-1)
        block_col = dst_col[3];  // Which 8x8 block horizontally (0-1)
        zz_idx = {dst_row[2:0], dst_col[2:0]};  // Position within 8x8 block (0-63)
        
        case (zz_idx)
            6'd0:  begin in_block_row = 3'd0; in_block_col = 3'd0; end
            6'd1:  begin in_block_row = 3'd0; in_block_col = 3'd1; end
            6'd2:  begin in_block_row = 3'd1; in_block_col = 3'd0; end
            6'd3:  begin in_block_row = 3'd2; in_block_col = 3'd0; end
            6'd4:  begin in_block_row = 3'd1; in_block_col = 3'd1; end
            6'd5:  begin in_block_row = 3'd0; in_block_col = 3'd2; end
            6'd6:  begin in_block_row = 3'd0; in_block_col = 3'd3; end
            6'd7:  begin in_block_row = 3'd1; in_block_col = 3'd2; end
            6'd8:  begin in_block_row = 3'd2; in_block_col = 3'd1; end
            6'd9:  begin in_block_row = 3'd3; in_block_col = 3'd0; end
            6'd10: begin in_block_row = 3'd4; in_block_col = 3'd0; end
            6'd11: begin in_block_row = 3'd3; in_block_col = 3'd1; end
            6'd12: begin in_block_row = 3'd2; in_block_col = 3'd2; end
            6'd13: begin in_block_row = 3'd1; in_block_col = 3'd3; end
            6'd14: begin in_block_row = 3'd0; in_block_col = 3'd4; end
            6'd15: begin in_block_row = 3'd0; in_block_col = 3'd5; end
            6'd16: begin in_block_row = 3'd1; in_block_col = 3'd4; end
            6'd17: begin in_block_row = 3'd2; in_block_col = 3'd3; end
            6'd18: begin in_block_row = 3'd3; in_block_col = 3'd2; end
            6'd19: begin in_block_row = 3'd4; in_block_col = 3'd1; end
            6'd20: begin in_block_row = 3'd5; in_block_col = 3'd0; end
            6'd21: begin in_block_row = 3'd6; in_block_col = 3'd0; end
            6'd22: begin in_block_row = 3'd5; in_block_col = 3'd1; end
            6'd23: begin in_block_row = 3'd4; in_block_col = 3'd2; end
            6'd24: begin in_block_row = 3'd3; in_block_col = 3'd3; end
            6'd25: begin in_block_row = 3'd2; in_block_col = 3'd4; end
            6'd26: begin in_block_row = 3'd1; in_block_col = 3'd5; end
            6'd27: begin in_block_row = 3'd0; in_block_col = 3'd6; end
            6'd28: begin in_block_row = 3'd0; in_block_col = 3'd7; end
            6'd29: begin in_block_row = 3'd1; in_block_col = 3'd6; end
            6'd30: begin in_block_row = 3'd2; in_block_col = 3'd5; end
            6'd31: begin in_block_row = 3'd3; in_block_col = 3'd4; end
            6'd32: begin in_block_row = 3'd4; in_block_col = 3'd3; end
            6'd33: begin in_block_row = 3'd5; in_block_col = 3'd2; end
            6'd34: begin in_block_row = 3'd6; in_block_col = 3'd1; end
            6'd35: begin in_block_row = 3'd7; in_block_col = 3'd0; end
            6'd36: begin in_block_row = 3'd7; in_block_col = 3'd1; end
            6'd37: begin in_block_row = 3'd6; in_block_col = 3'd2; end
            6'd38: begin in_block_row = 3'd5; in_block_col = 3'd3; end
            6'd39: begin in_block_row = 3'd4; in_block_col = 3'd4; end
            6'd40: begin in_block_row = 3'd3; in_block_col = 3'd5; end
            6'd41: begin in_block_row = 3'd2; in_block_col = 3'd6; end
            6'd42: begin in_block_row = 3'd1; in_block_col = 3'd7; end
            6'd43: begin in_block_row = 3'd2; in_block_col = 3'd7; end
            6'd44: begin in_block_row = 3'd3; in_block_col = 3'd6; end
            6'd45: begin in_block_row = 3'd4; in_block_col = 3'd5; end
            6'd46: begin in_block_row = 3'd5; in_block_col = 3'd4; end
            6'd47: begin in_block_row = 3'd6; in_block_col = 3'd3; end
            6'd48: begin in_block_row = 3'd7; in_block_col = 3'd2; end
            6'd49: begin in_block_row = 3'd7; in_block_col = 3'd3; end
            6'd50: begin in_block_row = 3'd6; in_block_col = 3'd4; end
            6'd51: begin in_block_row = 3'd5; in_block_col = 3'd5; end
            6'd52: begin in_block_row = 3'd4; in_block_col = 3'd6; end
            6'd53: begin in_block_row = 3'd3; in_block_col = 3'd7; end
            6'd54: begin in_block_row = 3'd4; in_block_col = 3'd7; end
            6'd55: begin in_block_row = 3'd5; in_block_col = 3'd6; end
            6'd56: begin in_block_row = 3'd6; in_block_col = 3'd5; end
            6'd57: begin in_block_row = 3'd7; in_block_col = 3'd4; end
            6'd58: begin in_block_row = 3'd7; in_block_col = 3'd5; end
            6'd59: begin in_block_row = 3'd6; in_block_col = 3'd6; end
            6'd60: begin in_block_row = 3'd5; in_block_col = 3'd7; end
            6'd61: begin in_block_row = 3'd6; in_block_col = 3'd7; end
            6'd62: begin in_block_row = 3'd7; in_block_col = 3'd6; end
            6'd63: begin in_block_row = 3'd7; in_block_col = 3'd7; end
        endcase
        
        zigzag8_row = {block_row, in_block_row};
    end
endfunction

function [3:0] zigzag8_col;
    input [3:0] dst_row, dst_col;
    reg [0:0] block_row, block_col;
    reg [2:0] in_block_row, in_block_col;
    reg [5:0] zz_idx;
    begin
        block_row = dst_row[3];
        block_col = dst_col[3];
        zz_idx = {dst_row[2:0], dst_col[2:0]};
        
        case (zz_idx)
            6'd0:  begin in_block_row = 3'd0; in_block_col = 3'd0; end
            6'd1:  begin in_block_row = 3'd0; in_block_col = 3'd1; end
            6'd2:  begin in_block_row = 3'd1; in_block_col = 3'd0; end
            6'd3:  begin in_block_row = 3'd2; in_block_col = 3'd0; end
            6'd4:  begin in_block_row = 3'd1; in_block_col = 3'd1; end
            6'd5:  begin in_block_row = 3'd0; in_block_col = 3'd2; end
            6'd6:  begin in_block_row = 3'd0; in_block_col = 3'd3; end
            6'd7:  begin in_block_row = 3'd1; in_block_col = 3'd2; end
            6'd8:  begin in_block_row = 3'd2; in_block_col = 3'd1; end
            6'd9:  begin in_block_row = 3'd3; in_block_col = 3'd0; end
            6'd10: begin in_block_row = 3'd4; in_block_col = 3'd0; end
            6'd11: begin in_block_row = 3'd3; in_block_col = 3'd1; end
            6'd12: begin in_block_row = 3'd2; in_block_col = 3'd2; end
            6'd13: begin in_block_row = 3'd1; in_block_col = 3'd3; end
            6'd14: begin in_block_row = 3'd0; in_block_col = 3'd4; end
            6'd15: begin in_block_row = 3'd0; in_block_col = 3'd5; end
            6'd16: begin in_block_row = 3'd1; in_block_col = 3'd4; end
            6'd17: begin in_block_row = 3'd2; in_block_col = 3'd3; end
            6'd18: begin in_block_row = 3'd3; in_block_col = 3'd2; end
            6'd19: begin in_block_row = 3'd4; in_block_col = 3'd1; end
            6'd20: begin in_block_row = 3'd5; in_block_col = 3'd0; end
            6'd21: begin in_block_row = 3'd6; in_block_col = 3'd0; end
            6'd22: begin in_block_row = 3'd5; in_block_col = 3'd1; end
            6'd23: begin in_block_row = 3'd4; in_block_col = 3'd2; end
            6'd24: begin in_block_row = 3'd3; in_block_col = 3'd3; end
            6'd25: begin in_block_row = 3'd2; in_block_col = 3'd4; end
            6'd26: begin in_block_row = 3'd1; in_block_col = 3'd5; end
            6'd27: begin in_block_row = 3'd0; in_block_col = 3'd6; end
            6'd28: begin in_block_row = 3'd0; in_block_col = 3'd7; end
            6'd29: begin in_block_row = 3'd1; in_block_col = 3'd6; end
            6'd30: begin in_block_row = 3'd2; in_block_col = 3'd5; end
            6'd31: begin in_block_row = 3'd3; in_block_col = 3'd4; end
            6'd32: begin in_block_row = 3'd4; in_block_col = 3'd3; end
            6'd33: begin in_block_row = 3'd5; in_block_col = 3'd2; end
            6'd34: begin in_block_row = 3'd6; in_block_col = 3'd1; end
            6'd35: begin in_block_row = 3'd7; in_block_col = 3'd0; end
            6'd36: begin in_block_row = 3'd7; in_block_col = 3'd1; end
            6'd37: begin in_block_row = 3'd6; in_block_col = 3'd2; end
            6'd38: begin in_block_row = 3'd5; in_block_col = 3'd3; end
            6'd39: begin in_block_row = 3'd4; in_block_col = 3'd4; end
            6'd40: begin in_block_row = 3'd3; in_block_col = 3'd5; end
            6'd41: begin in_block_row = 3'd2; in_block_col = 3'd6; end
            6'd42: begin in_block_row = 3'd1; in_block_col = 3'd7; end
            6'd43: begin in_block_row = 3'd2; in_block_col = 3'd7; end
            6'd44: begin in_block_row = 3'd3; in_block_col = 3'd6; end
            6'd45: begin in_block_row = 3'd4; in_block_col = 3'd5; end
            6'd46: begin in_block_row = 3'd5; in_block_col = 3'd4; end
            6'd47: begin in_block_row = 3'd6; in_block_col = 3'd3; end
            6'd48: begin in_block_row = 3'd7; in_block_col = 3'd2; end
            6'd49: begin in_block_row = 3'd7; in_block_col = 3'd3; end
            6'd50: begin in_block_row = 3'd6; in_block_col = 3'd4; end
            6'd51: begin in_block_row = 3'd5; in_block_col = 3'd5; end
            6'd52: begin in_block_row = 3'd4; in_block_col = 3'd6; end
            6'd53: begin in_block_row = 3'd3; in_block_col = 3'd7; end
            6'd54: begin in_block_row = 3'd4; in_block_col = 3'd7; end
            6'd55: begin in_block_row = 3'd5; in_block_col = 3'd6; end
            6'd56: begin in_block_row = 3'd6; in_block_col = 3'd5; end
            6'd57: begin in_block_row = 3'd7; in_block_col = 3'd4; end
            6'd58: begin in_block_row = 3'd7; in_block_col = 3'd5; end
            6'd59: begin in_block_row = 3'd6; in_block_col = 3'd6; end
            6'd60: begin in_block_row = 3'd5; in_block_col = 3'd7; end
            6'd61: begin in_block_row = 3'd6; in_block_col = 3'd7; end
            6'd62: begin in_block_row = 3'd7; in_block_col = 3'd6; end
            6'd63: begin in_block_row = 3'd7; in_block_col = 3'd7; end
        endcase
        
        zigzag8_col = {block_col, in_block_col};
    end
endfunction

//==================================================================
// 4x4 Morton Order
//==================================================================
function [3:0] morton4_row;
    input [3:0] dst_row, dst_col;
    reg [1:0] block_row, block_col;
    reg [1:0] in_block_row, in_block_col;
    reg [3:0] morton_idx;
    begin
        block_row = dst_row[3:2];
        block_col = dst_col[3:2];
        morton_idx = {dst_row[1:0], dst_col[1:0]};
        
        // Morton order inverse mapping
        case (morton_idx)
            4'd0:  begin in_block_row = 2'd0; in_block_col = 2'd0; end
            4'd1:  begin in_block_row = 2'd0; in_block_col = 2'd1; end
            4'd2:  begin in_block_row = 2'd1; in_block_col = 2'd0; end
            4'd3:  begin in_block_row = 2'd1; in_block_col = 2'd1; end
            4'd4:  begin in_block_row = 2'd0; in_block_col = 2'd2; end
            4'd5:  begin in_block_row = 2'd0; in_block_col = 2'd3; end
            4'd6:  begin in_block_row = 2'd1; in_block_col = 2'd2; end
            4'd7:  begin in_block_row = 2'd1; in_block_col = 2'd3; end
            4'd8:  begin in_block_row = 2'd2; in_block_col = 2'd0; end
            4'd9:  begin in_block_row = 2'd2; in_block_col = 2'd1; end
            4'd10: begin in_block_row = 2'd3; in_block_col = 2'd0; end
            4'd11: begin in_block_row = 2'd3; in_block_col = 2'd1; end
            4'd12: begin in_block_row = 2'd2; in_block_col = 2'd2; end
            4'd13: begin in_block_row = 2'd2; in_block_col = 2'd3; end
            4'd14: begin in_block_row = 2'd3; in_block_col = 2'd2; end
            4'd15: begin in_block_row = 2'd3; in_block_col = 2'd3; end
        endcase
        
        morton4_row = {block_row, in_block_row};
    end
endfunction

function [3:0] morton4_col;
    input [3:0] dst_row, dst_col;
    reg [1:0] block_row, block_col;
    reg [1:0] in_block_row, in_block_col;
    reg [3:0] morton_idx;
    begin
        block_row = dst_row[3:2];
        block_col = dst_col[3:2];
        morton_idx = {dst_row[1:0], dst_col[1:0]};
        
        case (morton_idx)
            4'd0:  begin in_block_row = 2'd0; in_block_col = 2'd0; end
            4'd1:  begin in_block_row = 2'd0; in_block_col = 2'd1; end
            4'd2:  begin in_block_row = 2'd1; in_block_col = 2'd0; end
            4'd3:  begin in_block_row = 2'd1; in_block_col = 2'd1; end
            4'd4:  begin in_block_row = 2'd0; in_block_col = 2'd2; end
            4'd5:  begin in_block_row = 2'd0; in_block_col = 2'd3; end
            4'd6:  begin in_block_row = 2'd1; in_block_col = 2'd2; end
            4'd7:  begin in_block_row = 2'd1; in_block_col = 2'd3; end
            4'd8:  begin in_block_row = 2'd2; in_block_col = 2'd0; end
            4'd9:  begin in_block_row = 2'd2; in_block_col = 2'd1; end
            4'd10: begin in_block_row = 2'd3; in_block_col = 2'd0; end
            4'd11: begin in_block_row = 2'd3; in_block_col = 2'd1; end
            4'd12: begin in_block_row = 2'd2; in_block_col = 2'd2; end
            4'd13: begin in_block_row = 2'd2; in_block_col = 2'd3; end
            4'd14: begin in_block_row = 2'd3; in_block_col = 2'd2; end
            4'd15: begin in_block_row = 2'd3; in_block_col = 2'd3; end
        endcase
        
        morton4_col = {block_col, in_block_col};
    end
endfunction

//==================================================================
// 8x8 Morton Order 
//==================================================================
function [3:0] morton8_row;
    input [3:0] dst_row, dst_col;
    reg [0:0] block_row, block_col;
    reg [2:0] in_block_row, in_block_col;
    reg [5:0] morton_idx;
    begin
        block_row = dst_row[3];
        block_col = dst_col[3];
        morton_idx = {dst_row[2:0], dst_col[2:0]};
        
        case (morton_idx)
            6'd0:  begin in_block_row = 3'd0; in_block_col = 3'd0; end
            6'd1:  begin in_block_row = 3'd0; in_block_col = 3'd1; end
            6'd2:  begin in_block_row = 3'd1; in_block_col = 3'd0; end
            6'd3:  begin in_block_row = 3'd1; in_block_col = 3'd1; end
            6'd4:  begin in_block_row = 3'd0; in_block_col = 3'd2; end
            6'd5:  begin in_block_row = 3'd0; in_block_col = 3'd3; end
            6'd6:  begin in_block_row = 3'd1; in_block_col = 3'd2; end
            6'd7:  begin in_block_row = 3'd1; in_block_col = 3'd3; end
            6'd8:  begin in_block_row = 3'd2; in_block_col = 3'd0; end
            6'd9:  begin in_block_row = 3'd2; in_block_col = 3'd1; end
            6'd10: begin in_block_row = 3'd3; in_block_col = 3'd0; end
            6'd11: begin in_block_row = 3'd3; in_block_col = 3'd1; end
            6'd12: begin in_block_row = 3'd2; in_block_col = 3'd2; end
            6'd13: begin in_block_row = 3'd2; in_block_col = 3'd3; end
            6'd14: begin in_block_row = 3'd3; in_block_col = 3'd2; end
            6'd15: begin in_block_row = 3'd3; in_block_col = 3'd3; end
            6'd16: begin in_block_row = 3'd0; in_block_col = 3'd4; end
            6'd17: begin in_block_row = 3'd0; in_block_col = 3'd5; end
            6'd18: begin in_block_row = 3'd1; in_block_col = 3'd4; end
            6'd19: begin in_block_row = 3'd1; in_block_col = 3'd5; end
            6'd20: begin in_block_row = 3'd0; in_block_col = 3'd6; end
            6'd21: begin in_block_row = 3'd0; in_block_col = 3'd7; end
            6'd22: begin in_block_row = 3'd1; in_block_col = 3'd6; end
            6'd23: begin in_block_row = 3'd1; in_block_col = 3'd7; end
            6'd24: begin in_block_row = 3'd2; in_block_col = 3'd4; end
            6'd25: begin in_block_row = 3'd2; in_block_col = 3'd5; end
            6'd26: begin in_block_row = 3'd3; in_block_col = 3'd4; end
            6'd27: begin in_block_row = 3'd3; in_block_col = 3'd5; end
            6'd28: begin in_block_row = 3'd2; in_block_col = 3'd6; end
            6'd29: begin in_block_row = 3'd2; in_block_col = 3'd7; end
            6'd30: begin in_block_row = 3'd3; in_block_col = 3'd6; end
            6'd31: begin in_block_row = 3'd3; in_block_col = 3'd7; end
            6'd32: begin in_block_row = 3'd4; in_block_col = 3'd0; end
            6'd33: begin in_block_row = 3'd4; in_block_col = 3'd1; end
            6'd34: begin in_block_row = 3'd5; in_block_col = 3'd0; end
            6'd35: begin in_block_row = 3'd5; in_block_col = 3'd1; end
            6'd36: begin in_block_row = 3'd4; in_block_col = 3'd2; end
            6'd37: begin in_block_row = 3'd4; in_block_col = 3'd3; end
            6'd38: begin in_block_row = 3'd5; in_block_col = 3'd2; end
            6'd39: begin in_block_row = 3'd5; in_block_col = 3'd3; end
            6'd40: begin in_block_row = 3'd6; in_block_col = 3'd0; end
            6'd41: begin in_block_row = 3'd6; in_block_col = 3'd1; end
            6'd42: begin in_block_row = 3'd7; in_block_col = 3'd0; end
            6'd43: begin in_block_row = 3'd7; in_block_col = 3'd1; end
            6'd44: begin in_block_row = 3'd6; in_block_col = 3'd2; end
            6'd45: begin in_block_row = 3'd6; in_block_col = 3'd3; end
            6'd46: begin in_block_row = 3'd7; in_block_col = 3'd2; end
            6'd47: begin in_block_row = 3'd7; in_block_col = 3'd3; end
            6'd48: begin in_block_row = 3'd4; in_block_col = 3'd4; end
            6'd49: begin in_block_row = 3'd4; in_block_col = 3'd5; end
            6'd50: begin in_block_row = 3'd5; in_block_col = 3'd4; end
            6'd51: begin in_block_row = 3'd5; in_block_col = 3'd5; end
            6'd52: begin in_block_row = 3'd4; in_block_col = 3'd6; end
            6'd53: begin in_block_row = 3'd4; in_block_col = 3'd7; end
            6'd54: begin in_block_row = 3'd5; in_block_col = 3'd6; end
            6'd55: begin in_block_row = 3'd5; in_block_col = 3'd7; end
            6'd56: begin in_block_row = 3'd6; in_block_col = 3'd4; end
            6'd57: begin in_block_row = 3'd6; in_block_col = 3'd5; end
            6'd58: begin in_block_row = 3'd7; in_block_col = 3'd4; end
            6'd59: begin in_block_row = 3'd7; in_block_col = 3'd5; end
            6'd60: begin in_block_row = 3'd6; in_block_col = 3'd6; end
            6'd61: begin in_block_row = 3'd6; in_block_col = 3'd7; end
            6'd62: begin in_block_row = 3'd7; in_block_col = 3'd6; end
            6'd63: begin in_block_row = 3'd7; in_block_col = 3'd7; end
        endcase
        
        morton8_row = {block_row, in_block_row};
    end
endfunction

function [3:0] morton8_col;
    input [3:0] dst_row, dst_col;
    reg [0:0] block_row, block_col;
    reg [2:0] in_block_row, in_block_col;
    reg [5:0] morton_idx;
    begin
        block_row = dst_row[3];
        block_col = dst_col[3];
        morton_idx = {dst_row[2:0], dst_col[2:0]};
        
        case (morton_idx)
            6'd0:  begin in_block_row = 3'd0; in_block_col = 3'd0; end
            6'd1:  begin in_block_row = 3'd0; in_block_col = 3'd1; end
            6'd2:  begin in_block_row = 3'd1; in_block_col = 3'd0; end
            6'd3:  begin in_block_row = 3'd1; in_block_col = 3'd1; end
            6'd4:  begin in_block_row = 3'd0; in_block_col = 3'd2; end
            6'd5:  begin in_block_row = 3'd0; in_block_col = 3'd3; end
            6'd6:  begin in_block_row = 3'd1; in_block_col = 3'd2; end
            6'd7:  begin in_block_row = 3'd1; in_block_col = 3'd3; end
            6'd8:  begin in_block_row = 3'd2; in_block_col = 3'd0; end
            6'd9:  begin in_block_row = 3'd2; in_block_col = 3'd1; end
            6'd10: begin in_block_row = 3'd3; in_block_col = 3'd0; end
            6'd11: begin in_block_row = 3'd3; in_block_col = 3'd1; end
            6'd12: begin in_block_row = 3'd2; in_block_col = 3'd2; end
            6'd13: begin in_block_row = 3'd2; in_block_col = 3'd3; end
            6'd14: begin in_block_row = 3'd3; in_block_col = 3'd2; end
            6'd15: begin in_block_row = 3'd3; in_block_col = 3'd3; end
            6'd16: begin in_block_row = 3'd0; in_block_col = 3'd4; end
            6'd17: begin in_block_row = 3'd0; in_block_col = 3'd5; end
            6'd18: begin in_block_row = 3'd1; in_block_col = 3'd4; end
            6'd19: begin in_block_row = 3'd1; in_block_col = 3'd5; end
            6'd20: begin in_block_row = 3'd0; in_block_col = 3'd6; end
            6'd21: begin in_block_row = 3'd0; in_block_col = 3'd7; end
            6'd22: begin in_block_row = 3'd1; in_block_col = 3'd6; end
            6'd23: begin in_block_row = 3'd1; in_block_col = 3'd7; end
            6'd24: begin in_block_row = 3'd2; in_block_col = 3'd4; end
            6'd25: begin in_block_row = 3'd2; in_block_col = 3'd5; end
            6'd26: begin in_block_row = 3'd3; in_block_col = 3'd4; end
            6'd27: begin in_block_row = 3'd3; in_block_col = 3'd5; end
            6'd28: begin in_block_row = 3'd2; in_block_col = 3'd6; end
            6'd29: begin in_block_row = 3'd2; in_block_col = 3'd7; end
            6'd30: begin in_block_row = 3'd3; in_block_col = 3'd6; end
            6'd31: begin in_block_row = 3'd3; in_block_col = 3'd7; end
            6'd32: begin in_block_row = 3'd4; in_block_col = 3'd0; end
            6'd33: begin in_block_row = 3'd4; in_block_col = 3'd1; end
            6'd34: begin in_block_row = 3'd5; in_block_col = 3'd0; end
            6'd35: begin in_block_row = 3'd5; in_block_col = 3'd1; end
            6'd36: begin in_block_row = 3'd4; in_block_col = 3'd2; end
            6'd37: begin in_block_row = 3'd4; in_block_col = 3'd3; end
            6'd38: begin in_block_row = 3'd5; in_block_col = 3'd2; end
            6'd39: begin in_block_row = 3'd5; in_block_col = 3'd3; end
            6'd40: begin in_block_row = 3'd6; in_block_col = 3'd0; end
            6'd41: begin in_block_row = 3'd6; in_block_col = 3'd1; end
            6'd42: begin in_block_row = 3'd7; in_block_col = 3'd0; end
            6'd43: begin in_block_row = 3'd7; in_block_col = 3'd1; end
            6'd44: begin in_block_row = 3'd6; in_block_col = 3'd2; end
            6'd45: begin in_block_row = 3'd6; in_block_col = 3'd3; end
            6'd46: begin in_block_row = 3'd7; in_block_col = 3'd2; end
            6'd47: begin in_block_row = 3'd7; in_block_col = 3'd3; end
            6'd48: begin in_block_row = 3'd4; in_block_col = 3'd4; end
            6'd49: begin in_block_row = 3'd4; in_block_col = 3'd5; end
            6'd50: begin in_block_row = 3'd5; in_block_col = 3'd4; end
            6'd51: begin in_block_row = 3'd5; in_block_col = 3'd5; end
            6'd52: begin in_block_row = 3'd4; in_block_col = 3'd6; end
            6'd53: begin in_block_row = 3'd4; in_block_col = 3'd7; end
            6'd54: begin in_block_row = 3'd5; in_block_col = 3'd6; end
            6'd55: begin in_block_row = 3'd5; in_block_col = 3'd7; end
            6'd56: begin in_block_row = 3'd6; in_block_col = 3'd4; end
            6'd57: begin in_block_row = 3'd6; in_block_col = 3'd5; end
            6'd58: begin in_block_row = 3'd7; in_block_col = 3'd4; end
            6'd59: begin in_block_row = 3'd7; in_block_col = 3'd5; end
            6'd60: begin in_block_row = 3'd6; in_block_col = 3'd6; end
            6'd61: begin in_block_row = 3'd6; in_block_col = 3'd7; end
            6'd62: begin in_block_row = 3'd7; in_block_col = 3'd6; end
            6'd63: begin in_block_row = 3'd7; in_block_col = 3'd7; end
        endcase
        
        morton8_col = {block_col, in_block_col};
    end
endfunction
endmodule
