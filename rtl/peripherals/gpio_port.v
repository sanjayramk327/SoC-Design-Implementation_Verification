`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : gpio_port
// Description : 8-Bit GPIO Port with Direction, Data, & Interrupt Control (PICU)
//////////////////////////////////////////////////////////////////////////////////

module gpio_port
(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave
    input  wire [11:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [11:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // Internal Port Data Bus
    output reg  [7:0]  port_dr,
    input  wire [7:0]  port_ps,

    // Interrupt Output to REM / CPU
    output reg         port_irq
);

    wire [11:0] reg_addr;
    wire [31:0] reg_wdata;
    wire [3:0]  reg_wstrb;
    wire        reg_write_en;
    wire        reg_read_en;
    reg  [31:0] reg_rdata;

    axi4lite_slave #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) u_axislave (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wstrb(reg_wstrb),
        .reg_write_en(reg_write_en),
        .reg_read_en(reg_read_en),
        .reg_rdata(reg_rdata),
        .reg_ack(1'b1)
    );

    reg [7:0] intr_mask;
    reg [7:0] intr_stat;
    reg [7:0] ps_dly;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            port_dr   <= 8'h00;
            intr_mask <= 8'h00;
            intr_stat <= 8'h00;
            ps_dly    <= 8'h00;
            port_irq  <= 1'b0;
        end else begin
            ps_dly <= port_ps;

            // Edge detection on pin inputs
            intr_stat <= intr_stat | ((port_ps ^ ps_dly) & intr_mask);

            if (reg_write_en) begin
                case (reg_addr[7:0])
                    8'h00: port_dr   <= reg_wdata[7:0];
                    8'h08: intr_mask <= reg_wdata[7:0];
                    8'h0C: intr_stat <= intr_stat & ~reg_wdata[7:0]; // W1C
                    default: ;
                endcase
            end

            port_irq <= | intr_stat;
        end
    end

    always @(*) begin
        case (reg_addr[7:0])
            8'h00: reg_rdata = {24'h0, port_dr};
            8'h04: reg_rdata = {24'h0, port_ps};
            8'h08: reg_rdata = {24'h0, intr_mask};
            8'h0C: reg_rdata = {24'h0, intr_stat};
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
