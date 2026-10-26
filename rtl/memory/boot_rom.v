`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : boot_rom
// Description : Supervisory Boot ROM (8KB = 2048 words x 32 bits) with AXI4-Lite
//////////////////////////////////////////////////////////////////////////////////

module boot_rom
#(
    parameter ADDR_WIDTH = 13,
    parameter DATA_WIDTH = 32
)
(
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXI4-Lite Slave Interface
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready
);

    reg [31:0] rom [0:2047];

    // Initialize with standard startup routine
    // Program:
    // 0: lui x1, 0x20000    # x1 = 0x20000000 (SRAM Base)
    // 1: addi x2, x0, 100   # x2 = 100
    // 2: sw x2, 0(x1)       # mem[0x20000000] = 100
    // 3: lw x3, 0(x1)       # x3 = mem[0x20000000]
    // 4: jal x0, 12         # jump to main loop in ROM or SRAM
    integer j;
    initial begin
        for (j = 0; j < 2048; j = j + 1)
            rom[j] = 32'h00000013; // nop (addi x0, x0, 0)
        // Bootstrap sequence in hex
        rom[0] = 32'h200000B7; // lui x1, 0x20000
        rom[1] = 32'h06400113; // addi x2, x0, 100
        rom[2] = 32'h0020A023; // sw x2, 0(x1)
        rom[3] = 32'h0000A183; // lw x3, 0(x1)
        rom[4] = 32'h0040006F; // jal x0, 4 (loop)
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                s_axi_rdata  <= rom[s_axi_araddr[12:2]];
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
