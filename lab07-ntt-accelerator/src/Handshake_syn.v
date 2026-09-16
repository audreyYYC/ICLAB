module Handshake_syn #(parameter WIDTH=32) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output reg sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output flag_handshake_to_clk1;
input  flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input  flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;

always @(posedge sclk or negedge rst_n) begin
    if(!rst_n)
        sidle <= 1;
    else begin
        if(sready || sack || sreq)
            sidle <= 0;
        else
            sidle <= 1;
    end
end

reg flag;
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) begin
        dvalid <= 0;
        flag <= 0;
    end
    else begin
        if(dreq && (!dbusy) && dack) begin
            flag <= 1;
            if(!flag)
                dvalid <= 1;
            else
                dvalid <= 0;
        end
        else begin
            dvalid <= 0;
            flag <= 0;
        end
    end
end

always @(posedge dclk or negedge rst_n) begin
    if(!rst_n)
        dout <= 0;
    else begin
        if(dreq && (!dbusy))
            dout <= din;
    end
end

always @(posedge sclk or negedge rst_n) begin
    if(!rst_n)
        sreq <= 0;
    else begin
        if(sack)
            sreq <= 0;
        else if(sready)
            sreq <= 1;
    end
end

always @(posedge dclk or negedge rst_n)begin
    if(!rst_n)
        dack <= 0;
    else begin
        if(dreq && ((!dbusy) || dack))
            dack <= 1;
        else
            dack <= 0;
    end
end

NDFF_syn nd_req(.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n));
NDFF_syn nd_ack(.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

endmodule