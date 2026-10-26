`timescale 1ns / 1ps

module riscv_regfile
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  raddr1,
    output wire [31:0] rdata1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata2,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata
);

    reg [31:0] rf [0:31];

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 32'h0;
        end else if (we && (waddr != 5'd0)) begin
            rf[waddr] <= wdata;
        end
    end

    assign rdata1 = (raddr1 == 5'd0) ? 32'h0 : rf[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'h0 : rf[raddr2];

endmodule
