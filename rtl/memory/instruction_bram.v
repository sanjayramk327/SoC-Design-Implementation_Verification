`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : instruction_bram
// Description : Zero-Wait-State Dual-Port SRAM (32KB = 8192 x 32 bits)
//               Port A: Dedicated Fast CPU Instruction Fetch Port
//               Port B: AXI4-Lite Slave Port (for DMA/CPU data access)
//////////////////////////////////////////////////////////////////////////////////

module instruction_bram
#(
    parameter ADDR_WIDTH = 15, // 32KB
    parameter DATA_WIDTH = 32
)
(
    input  wire                  clk,
    input  wire                  rst_n,

    // Port A: Direct Fast Instruction Fetch
    input  wire [ADDR_WIDTH-1:0] ifetch_addr,
    input  wire                  ifetch_en,
    output reg  [DATA_WIDTH-1:0] ifetch_rdata,

    // Port B: AXI4-Lite Interface
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready
);

    reg [31:0] ram [0:8191];

    integer m;
    initial begin
        for (m = 0; m < 8192; m = m + 1)
            ram[m] = 32'h00000013;
    end

    // Port A: Synchronous Read
    always @(posedge clk) begin
        if (ifetch_en)
            ifetch_rdata <= ram[ifetch_addr[14:2]];
    end

    // Port B: AXI4-Lite Slave Handshake & Read/Write
    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg                  aw_en;

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
            awaddr_reg    <= 0;
            aw_en         <= 1'b1;
        end else begin
            // Write Channel
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                awaddr_reg    <= s_axi_awaddr;
                aw_en         <= 1'b0;
                // Byte writes
                if (s_axi_wstrb[0]) ram[s_axi_awaddr[14:2]][7:0]   <= s_axi_wdata[7:0];
                if (s_axi_wstrb[1]) ram[s_axi_awaddr[14:2]][15:8]  <= s_axi_wdata[15:8];
                if (s_axi_wstrb[2]) ram[s_axi_awaddr[14:2]][23:16] <= s_axi_wdata[23:16];
                if (s_axi_wstrb[3]) ram[s_axi_awaddr[14:2]][31:24] <= s_axi_wdata[31:24];
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
                s_axi_rdata  <= ram[s_axi_araddr[14:2]];
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
