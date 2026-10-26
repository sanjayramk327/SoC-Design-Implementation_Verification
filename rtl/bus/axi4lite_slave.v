`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : axi4lite_slave
// Description : Generic AXI4-Lite Slave Adapter for MorphoSoC Peripherals
//////////////////////////////////////////////////////////////////////////////////

module axi4lite_slave
#(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
)
(
    input  wire                      aclk,
    input  wire                      aresetn,

    // AXI4-Lite Write Address
    input  wire [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                s_axi_awprot,
    input  wire                      s_axi_awvalid,
    output reg                       s_axi_awready,

    // AXI4-Lite Write Data
    input  wire [DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                      s_axi_wvalid,
    output reg                       s_axi_wready,

    // AXI4-Lite Write Response
    output reg  [1:0]                s_axi_bresp,
    output reg                       s_axi_bvalid,
    input  wire                      s_axi_bready,

    // AXI4-Lite Read Address
    input  wire [ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                s_axi_arprot,
    input  wire                      s_axi_arvalid,
    output reg                       s_axi_arready,

    // AXI4-Lite Read Data
    output reg  [DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                s_axi_rresp,
    output reg                       s_axi_rvalid,
    input  wire                      s_axi_rready,

    // Internal Register Interface
    output wire [ADDR_WIDTH-1:0]     reg_addr,
    output wire [DATA_WIDTH-1:0]     reg_wdata,
    output wire [(DATA_WIDTH/8)-1:0] reg_wstrb,
    output wire                      reg_write_en,
    output wire                      reg_read_en,
    input  wire [DATA_WIDTH-1:0]     reg_rdata,
    input  wire                      reg_ack
);

    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg                  aw_en;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            awaddr_reg    <= {ADDR_WIDTH{1'b0}};
            aw_en         <= 1'b1;
        end else begin
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                awaddr_reg    <= s_axi_awaddr;
                aw_en         <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bready && s_axi_bvalid)
                    aw_en <= 1'b1;
            end

            if (s_axi_awready && s_axi_wready && ~s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    assign reg_write_en = s_axi_awready && s_axi_wready;
    assign reg_addr     = s_axi_awready ? s_axi_awaddr : (s_axi_arready ? s_axi_araddr : araddr_reg);
    assign reg_wdata    = s_axi_wdata;
    assign reg_wstrb    = s_axi_wstrb;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
            araddr_reg    <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                araddr_reg    <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00; // OKAY
                s_axi_rdata  <= reg_rdata;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    assign reg_read_en = s_axi_arready;

endmodule
