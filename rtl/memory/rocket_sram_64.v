`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : rocket_sram_64
// Description : 64KB Dual-Port SRAM for Rocket RV64GC Core
//               Port A: 64-bit wide for Rocket instruction/data fetch
//               Port B: AXI4-Lite 32-bit slave for debug/DMA access
//////////////////////////////////////////////////////////////////////////////////

module rocket_sram_64
#(
    parameter DEPTH = 8192  // 8192 × 64-bit = 64KB
)
(
    input  wire        clk,
    input  wire        rst_n,

    // Port A: 64-bit Local Memory Interface (Rocket core)
    input  wire [63:0] a_addr,
    input  wire        a_ren,
    input  wire        a_wen,
    input  wire [63:0] a_wdata,
    input  wire [7:0]  a_wstrb,
    output reg  [63:0] a_rdata,

    // Port B: AXI4-Lite Slave (32-bit, for debug/DMA)
    input  wire [15:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [15:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    reg [63:0] ram [0:DEPTH-1];

    // Initialize with NOPs
    integer m;
    initial begin
        for (m = 0; m < DEPTH; m = m + 1)
            ram[m] = {32'h00000013, 32'h00000013};
    end

    // ===================================================================
    // Port A: 64-bit Synchronous Read/Write
    // ===================================================================
    wire [12:0] a_word_addr = a_addr[15:3];

    always @(posedge clk) begin
        if (a_ren)
            a_rdata <= ram[a_word_addr];

        if (a_wen) begin
            if (a_wstrb[0]) ram[a_word_addr][ 7: 0] <= a_wdata[ 7: 0];
            if (a_wstrb[1]) ram[a_word_addr][15: 8] <= a_wdata[15: 8];
            if (a_wstrb[2]) ram[a_word_addr][23:16] <= a_wdata[23:16];
            if (a_wstrb[3]) ram[a_word_addr][31:24] <= a_wdata[31:24];
            if (a_wstrb[4]) ram[a_word_addr][39:32] <= a_wdata[39:32];
            if (a_wstrb[5]) ram[a_word_addr][47:40] <= a_wdata[47:40];
            if (a_wstrb[6]) ram[a_word_addr][55:48] <= a_wdata[55:48];
            if (a_wstrb[7]) ram[a_word_addr][63:56] <= a_wdata[63:56];
        end
    end

    // ===================================================================
    // Port B: AXI4-Lite 32-bit Slave
    // ===================================================================
    reg        aw_en;
    reg [15:0] awaddr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
            awaddr_reg    <= 16'h0;
            aw_en         <= 1'b1;
        end else begin
            // Write Channel
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                awaddr_reg    <= s_axi_awaddr;
                aw_en         <= 1'b0;
                // Write 32-bit: select upper or lower half of 64-bit word
                if (s_axi_awaddr[2]) begin
                    if (s_axi_wstrb[0]) ram[s_axi_awaddr[15:3]][39:32] <= s_axi_wdata[ 7: 0];
                    if (s_axi_wstrb[1]) ram[s_axi_awaddr[15:3]][47:40] <= s_axi_wdata[15: 8];
                    if (s_axi_wstrb[2]) ram[s_axi_awaddr[15:3]][55:48] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) ram[s_axi_awaddr[15:3]][63:56] <= s_axi_wdata[31:24];
                end else begin
                    if (s_axi_wstrb[0]) ram[s_axi_awaddr[15:3]][ 7: 0] <= s_axi_wdata[ 7: 0];
                    if (s_axi_wstrb[1]) ram[s_axi_awaddr[15:3]][15: 8] <= s_axi_wdata[15: 8];
                    if (s_axi_wstrb[2]) ram[s_axi_awaddr[15:3]][23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) ram[s_axi_awaddr[15:3]][31:24] <= s_axi_wdata[31:24];
                end
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bready && s_axi_bvalid)
                    aw_en <= 1'b1;
            end

            if (s_axi_awready && s_axi_wready && ~s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            // Read Channel
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                if (s_axi_araddr[2])
                    s_axi_rdata <= ram[s_axi_araddr[15:3]][63:32];
                else
                    s_axi_rdata <= ram[s_axi_araddr[15:3]][31:0];
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
