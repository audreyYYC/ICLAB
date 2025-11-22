module FIFO_syn #(parameter WIDTH=16, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output reg flag_fifo_to_clk2;
input  flag_clk2_to_fifo;

output flag_fifo_to_clk3;
input  flag_clk3_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;
reg wptr_cnt;

reg [$clog2(WORDS):0] wptr_sync;
reg [$clog2(WORDS):0] rptr_sync;
wire [$clog2(WORDS)-1:0] waddr, raddr;

reg [$clog2(WORDS):0] wptr_bin;
reg [$clog2(WORDS):0] rptr_bin, rptr_bin_next;
reg [$clog2(WORDS):0] rptr_gray_next;


assign waddr = wptr_bin[$clog2(WORDS)-1:0];
assign raddr = rptr_bin_next[$clog2(WORDS)-1:0];

//---------------------------------------------------------------------
//   WRITE
//---------------------------------------------------------------------
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) begin
        wptr_bin <= 0;
    end
    else begin
        if(winc)
            wptr_bin <= wptr_bin + 1;
        else
            wptr_bin <= wptr_bin;
    end
end

// wptr to wptr_sync: 10.1 -> 20.7 (31)
always @(posedge wclk or negedge rst_n) begin
    if(!rst_n) begin
        wptr <= 0;
        wptr_cnt <= 0;
        flag_fifo_to_clk2 <= 0;
    end
    else begin
        //wptr <= (wptr_bin >> 1) ^ wptr_bin;
        //flag_fifo_to_clk2 <= (wptr == {~rptr_sync[$clog2(WORDS):$clog2(WORDS)-1], rptr_sync[$clog2(WORDS)-2:0]});
        
        if(wptr_cnt == 0) begin
            wptr <= (wptr_bin >> 1) ^ wptr_bin;
            wptr_cnt <= 1;  // Hold for 4 cycles ?? 2 cycle
            flag_fifo_to_clk2 <= 0;
        end
        else begin
            wptr_cnt <= wptr_cnt - 1;
            flag_fifo_to_clk2 <= 1;
        end
    end
end

always @(posedge wclk or negedge rst_n) begin
    if (!rst_n)
        wfull <= 0;
    else begin
        if(wptr == {~rptr_sync[$clog2(WORDS):$clog2(WORDS)-1], rptr_sync[$clog2(WORDS)-2:0]})
            wfull <= 1;
        else
            wfull <= 0;
    end
end

NDFF_BUS_syn #(.WIDTH($clog2(WORDS)+1)) read_ptr (
    .D(rptr), .Q(rptr_sync), .clk(wclk), .rst_n(rst_n)
);

//---------------------------------------------------------------------
//   READ
//---------------------------------------------------------------------
always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) begin
        rptr_bin <= 0;
        rptr <= 0;
    end
    else begin
        rptr_bin <= rptr_bin_next;
        rptr <= rptr_gray_next;
    end
end

always @(*) begin
    if(rinc)
        rptr_bin_next = rptr_bin + 1;
    else
        rptr_bin_next = rptr_bin;

    rptr_gray_next = (rptr_bin_next >> 1) ^ rptr_bin_next;
end

always @(posedge rclk or negedge rst_n) begin
    if (!rst_n)
        rempty <= 1;
    else begin
        if(rptr_gray_next == wptr_sync)
            rempty <= 1;
        else
            rempty <= 0;
    end
end

NDFF_BUS_syn #(.WIDTH($clog2(WORDS)+1)) write_ptr (
    .D(wptr), .Q(wptr_sync), .clk(rclk), .rst_n(rst_n)
);

//---------------------------------------------------------------------
//   OUTPUT
//---------------------------------------------------------------------
// rdata - Add one more register stage to rdata
always @(posedge rclk or negedge rst_n) begin
    if (!rst_n)
        rdata <= 0;
    else
        rdata <= rdata_q;
end

//---------------------------------------------------------------------
//   DUAL PORT SRAM
//---------------------------------------------------------------------
DUAL_64X16X1BM1 u_dual_sram (
    // Write port
    .CKA(wclk),
    .WEAN(!(winc)),// && !wfull)),           // Write enable (active low)
    .CSA(1'b1),            
    .OEA(1'b1),           
    .A0(waddr[0]),
    .A1(waddr[1]),
    .A2(waddr[2]),
    .A3(waddr[3]),
    .A4(waddr[4]),
    .A5(waddr[5]),
    .DIA0(wdata[0]),
    .DIA1(wdata[1]),
    .DIA2(wdata[2]),
    .DIA3(wdata[3]),
    .DIA4(wdata[4]),
    .DIA5(wdata[5]),
    .DIA6(wdata[6]),
    .DIA7(wdata[7]),
    .DIA8(wdata[8]),
    .DIA9(wdata[9]),
    .DIA10(wdata[10]),
    .DIA11(wdata[11]),
    .DIA12(wdata[12]),
    .DIA13(wdata[13]),
    .DIA14(wdata[14]),
    .DIA15(wdata[15]),
    .DOA0(),               // Write port output not used
    .DOA1(),
    .DOA2(),
    .DOA3(),
    .DOA4(),
    .DOA5(),
    .DOA6(),
    .DOA7(),
    .DOA8(),
    .DOA9(),
    .DOA10(),
    .DOA11(),
    .DOA12(),
    .DOA13(),
    .DOA14(),
    .DOA15(),
    
    // Read port
    .CKB(rclk),
    .WEBN(1'b1),           // Write enable (always disabled for read port)
    .CSB(1'b1),
    .OEB(1'b1),
    .B0(raddr[0]),
    .B1(raddr[1]),
    .B2(raddr[2]),
    .B3(raddr[3]),
    .B4(raddr[4]),
    .B5(raddr[5]),
    .DIB0(1'b0),           // Read port input not used
    .DIB1(1'b0),
    .DIB2(1'b0),
    .DIB3(1'b0),
    .DIB4(1'b0),
    .DIB5(1'b0),
    .DIB6(1'b0),
    .DIB7(1'b0),
    .DIB8(1'b0),
    .DIB9(1'b0),
    .DIB10(1'b0),
    .DIB11(1'b0),
    .DIB12(1'b0),
    .DIB13(1'b0),
    .DIB14(1'b0),
    .DIB15(1'b0),
    .DOB0(rdata_q[0]),
    .DOB1(rdata_q[1]),
    .DOB2(rdata_q[2]),
    .DOB3(rdata_q[3]),
    .DOB4(rdata_q[4]),
    .DOB5(rdata_q[5]),
    .DOB6(rdata_q[6]),
    .DOB7(rdata_q[7]),
    .DOB8(rdata_q[8]),
    .DOB9(rdata_q[9]),
    .DOB10(rdata_q[10]),
    .DOB11(rdata_q[11]),
    .DOB12(rdata_q[12]),
    .DOB13(rdata_q[13]),
    .DOB14(rdata_q[14]),
    .DOB15(rdata_q[15])
);


endmodule