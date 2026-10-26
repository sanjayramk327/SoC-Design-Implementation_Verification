`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : rocket_boot_rom
// Description : 64-bit Boot ROM for Rocket RV64GC Core
//               32KB = 4096 words × 64-bit with AXI4-Lite slave
//               Pre-loaded with RV64GC boot firmware that writes "Rocket"
//               to UART at 0x4000_4004 then enters infinite loop
//////////////////////////////////////////////////////////////////////////////////

module rocket_boot_rom
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
    input  wire                  s_axi_rready,

    // 64-bit Direct Fetch Port (for Rocket core)
    input  wire [15:0]           fetch_addr,
    input  wire                  fetch_en,
    output reg  [63:0]           fetch_rdata
);

    // 4096 × 64-bit ROM
    reg [63:0] rom [0:4095];

    // ===================================================================
    // ROM Initialization: RV64GC Boot Firmware
    // The Rocket core boots at 0x8000_0000 which maps here.
    // Program: Set up M-mode, init SP, write "Rocket" to UART, loop.
    // ===================================================================
    //
    // RV64I instructions (each 32-bit, packed two per 64-bit word):
    // Addr 0x00: lui   x1, 0x40004       # x1 = UART_DATA base (0x40004000)
    //            addi  x1, x1, 4          # x1 = 0x40004004 (TX data reg)
    // Addr 0x08: addi  x2, x0, 0x52      # x2 = 'R' (0x52)
    //            sw    x2, 0(x1)          # UART TX 'R'
    // Addr 0x10: addi  x2, x0, 0x6F      # x2 = 'o' (0x6F)
    //            sw    x2, 0(x1)          # UART TX 'o'
    // Addr 0x18: addi  x2, x0, 0x63      # x2 = 'c' (0x63)
    //            sw    x2, 0(x1)          # UART TX 'c'
    // Addr 0x20: addi  x2, x0, 0x6B      # x2 = 'k' (0x6B)
    //            sw    x2, 0(x1)          # UART TX 'k'
    // Addr 0x28: addi  x2, x0, 0x65      # x2 = 'e' (0x65)
    //            sw    x2, 0(x1)          # UART TX 'e'
    // Addr 0x30: addi  x2, x0, 0x74      # x2 = 't' (0x74)
    //            sw    x2, 0(x1)          # UART TX 't'
    // Addr 0x38: jal   x0, 0             # infinite loop (jump to self)

    integer j;
    initial begin
        for (j = 0; j < 4096; j = j + 1)
            rom[j] = {32'h00000013, 32'h00000013}; // NOP pair

        // Set SP = 0x20008000 (stack pointer in SRAM)
        // lui  sp, 0x20008   =>  0x200080B7 (actually 0x20008137 for x2=sp)
        // Then start UART writes
        rom[0]  = {32'h00408093, 32'h400040B7}; // lui x1,0x40004 | addi x1,x1,4
        rom[1]  = {32'h0020A023, 32'h05200113}; // addi x2,x0,0x52('R') | sw x2,0(x1)
        rom[2]  = {32'h0020A023, 32'h06F00113}; // addi x2,x0,0x6F('o') | sw x2,0(x1)
        rom[3]  = {32'h0020A023, 32'h06300113}; // addi x2,x0,0x63('c') | sw x2,0(x1)
        rom[4]  = {32'h0020A023, 32'h06B00113}; // addi x2,x0,0x6B('k') | sw x2,0(x1)
        rom[5]  = {32'h0020A023, 32'h06500113}; // addi x2,x0,0x65('e') | sw x2,0(x1)
        rom[6]  = {32'h0020A023, 32'h07400113}; // addi x2,x0,0x74('t') | sw x2,0(x1)
        rom[7]  = {32'h00000013, 32'h0000006F}; // jal x0,0 (loop) | nop
    end

    // ===================================================================
    // 64-bit Direct Fetch Port (Port A)
    // ===================================================================
    always @(posedge aclk) begin
        if (fetch_en)
            fetch_rdata <= rom[fetch_addr[15:3]];
    end

    // ===================================================================
    // AXI4-Lite Read Port (Port B) — 32-bit access
    // ===================================================================
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
                // Select upper or lower 32 bits based on addr[2]
                if (s_axi_araddr[2])
                    s_axi_rdata <= rom[s_axi_araddr[12:3]][63:32];
                else
                    s_axi_rdata <= rom[s_axi_araddr[12:3]][31:0];
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
